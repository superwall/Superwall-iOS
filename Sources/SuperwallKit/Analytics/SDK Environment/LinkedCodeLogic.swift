//
//  LinkedCodeLogic.swift
//  SuperwallKit
//
//  Created by Jake Mor on 23/10/2026.
//

import Foundation
import MachO
import ObjectiveC

/// Finds the third-party SDKs linked into the app's own code, from the names of
/// the Objective-C runtime classes in it.
///
/// Swift Package Manager links SDKs statically by default, so most never show up as
/// an embedded framework. Their classes do: Swift classes by module, and
/// Objective-C classes by name. Objective-C class names are unique in a process, so
/// each one belongs to exactly one SDK, which the server looks up by its hash.
/// Apple's modules are left out: only third-party SDKs can have an integration or
/// conflict with Superwall. Apple's Objective-C classes live outside the app, so
/// they're never in the images that are read.
enum LinkedCodeLogic {
  /// The class names in the app's images, by where they were found.
  struct AppClassNames: Equatable {
    /// From the app's executable and, in a debug build, the `<App>.debug.dylib`
    /// that holds the app's code. They're loaded before the app runs, so a build
    /// gives the same names every time.
    var executable: [String] = []
    /// From the embedded frameworks and other images that were loaded when the
    /// names were read. One the app loads later on isn't in it.
    var embedded: [String] = []

    var all: [String] {
      return executable + embedded
    }
  }

  /// SuperwallKit and the modules it brings in.
  static let superwallModules: Set<String> = [
    String(String(reflecting: LinkedCodeLogic.self).prefix { $0 != "." }),
    "Superscript"
  ]
  /// The `@objc(SWK…)` names SuperwallKit gives its own classes.
  static let superwallPrefixes: Set<String> = ["SWK"]
  /// What the mangling uses for the standard library and imported C and
  /// Objective-C types.
  private static let runtimeModules: Set<String> = ["Swift", "__C"]

  // MARK: - Class names

  /// The runtime names of the classes in the images inside `bundleURL`.
  ///
  /// That's the main executable, in a debug build the `<App>.debug.dylib` that holds
  /// the app's code, and the embedded frameworks, which can hold SDKs too: CocoaPods
  /// builds each pod as one, and an app split into its own frameworks can link SDKs
  /// into them. See ``isThirdPartyImage(atRelativePath:)`` for what's skipped.
  ///
  /// `objc_copyClassNamesForImage` reads the names without realizing the classes,
  /// unlike `objc_getClassList`. Swift classes that don't inherit from `NSObject`
  /// aren't Objective-C runtime classes, so a module made only of those isn't seen.
  static func appClassNames(bundleURL: URL) -> AppClassNames {
    let bundlePrefixes = pathPrefixes(of: bundleURL)

    var names = AppClassNames()
    for index in 0..<_dyld_image_count() {
      guard let imageName = _dyld_get_image_name(index) else {
        continue
      }
      // Only a string compare per image: most images are in the shared cache,
      // and resolving every path would touch the disk hundreds of times.
      guard
        let path = relativePath(of: String(cString: imageName), in: bundlePrefixes),
        isThirdPartyImage(atRelativePath: path)
      else {
        continue
      }
      // Each call scans the loaded images for this one by path. That's about half
      // a millisecond natively, but tens of milliseconds in the Simulator.
      var count: UInt32 = 0
      guard let classNames = objc_copyClassNamesForImage(imageName, &count) else {
        continue
      }
      defer { free(classNames) }
      let imageNames = (0..<Int(count)).map { String(cString: classNames[$0]) }
      if isExecutableImage(atRelativePath: path) {
        names.executable += imageNames
      } else {
        names.embedded += imageNames
      }
    }
    return names
  }

  /// Whether the image at `path`, relative to the app bundle, is the app's
  /// executable or the `<App>.debug.dylib` beside it: at the top of the bundle on
  /// iOS, and in `Contents/MacOS` on a Mac.
  static func isExecutableImage(atRelativePath path: String) -> Bool {
    let components = path.split(separator: "/")
    return components.count == 1
      || (components.count == 3 && components.starts(with: ["Contents", "MacOS"]))
  }

  /// Whether to read the classes of the image at `path`, relative to the app bundle.
  ///
  /// Skips the Swift back-deployment `libswift*` dylibs Apple embeds, and
  /// SuperwallKit's own frameworks when they're embedded.
  static func isThirdPartyImage(atRelativePath path: String) -> Bool {
    let components = path.split(separator: "/")
    if let file = components.last,
      file.hasPrefix("libswift") {
      return false
    }
    return !components.contains { component in
      component.hasSuffix(".framework")
        && superwallModules.contains(String(component.dropLast(".framework".count)))
    }
  }

  /// The modules of Apple's frameworks and Swift libraries loaded in the process.
  static func loadedSystemModules() -> Set<String> {
    var modules: Set<String> = []
    for index in 0..<_dyld_image_count() {
      guard let imageName = _dyld_get_image_name(index) else {
        continue
      }
      if let module = systemModule(atImagePath: String(cString: imageName)) {
        modules.insert(module)
      }
    }
    return modules
  }

  /// The module of an Apple framework or Swift library, from where it's loaded:
  /// `/System/Library/Frameworks/SwiftUI.framework/SwiftUI` or
  /// `/usr/lib/swift/libswift_Concurrency.dylib`. The paths also appear under the
  /// Simulator's runtime root and Mac Catalyst's `iOSSupport`.
  static func systemModule(atImagePath path: String) -> String? {
    let components = path.split(separator: "/")
    if path.contains("/System/Library/Frameworks/")
      || path.contains("/System/Library/PrivateFrameworks/") {
      return components
        .first { $0.hasSuffix(".framework") }
        .map { String($0.dropLast(".framework".count)) }
    }
    if path.contains("/usr/lib/swift/"),
      let file = components.last,
      file.hasPrefix("libswift"),
      file.hasSuffix(".dylib") {
      let module = String(file.dropFirst("libswift".count).dropLast(".dylib".count))
      // The standard library's module is `Swift`, in `libswiftCore`.
      return module == "Core" ? "Swift" : module
    }
    return nil
  }

  /// The bundle's path, and the same path with and without `/private`, since dyld
  /// and `Bundle` can disagree on it.
  private static func pathPrefixes(of url: URL) -> [String] {
    let path = url.path
    let resolved = url.resolvingSymlinksInPath().path
    return Array(Set([path, resolved, "/private" + resolved])).map { $0 + "/" }
  }

  private static func relativePath(of path: String, in prefixes: [String]) -> String? {
    guard let prefix = prefixes.first(where: { path.hasPrefix($0) }) else {
      return nil
    }
    return String(path.dropFirst(prefix.count))
  }

  // MARK: - Modules and Objective-C classes

  /// The third-party Swift modules and Objective-C class names in `classNames`,
  /// each deduplicated and sorted by UTF-8 bytes.
  ///
  /// Leaves out `excludedModules`, `systemModules`, any module starting with `_`,
  /// SuperwallKit and its dependencies, and SuperwallKit's Objective-C classes.
  /// The app's own Objective-C classes stay in: nothing in the class list reliably
  /// tells them apart from a dependency's.
  static func modulesAndObjCClassNames(
    in classNames: [String],
    excludedModules: Set<String>,
    systemModules: Set<String>
  ) -> (modules: [String], objcClassNames: [String]) {
    let excluded = excludedModules
      .union(systemModules)
      .union(superwallModules)
      .union(runtimeModules)
    var modules: Set<String> = []
    var objcClassNames: Set<String> = []

    for name in classNames {
      if let module = swiftModule(ofClassName: name) {
        // Underscored modules are the toolchain's, such as `_Concurrency`.
        if !excluded.contains(module),
          !module.hasPrefix("_") {
          modules.insert(module)
        }
      } else if isThirdPartyObjCClass(name) {
        objcClassNames.insert(name)
      }
    }
    return (sortedByUTF8(modules), sortedByUTF8(objcClassNames))
  }

  /// Leaves out underscored names, which are private to the toolchain, and classes
  /// with SuperwallKit's prefix.
  ///
  /// A prefix Apple also uses doesn't rule a class out. Only images inside the app
  /// are read, and plenty of SDKs share Apple's letters: Mantle's `MTLModel`,
  /// LeanCloud's `AVUser`, ComponentKit's `CKComponent`.
  static func isThirdPartyObjCClass(_ name: String) -> Bool {
    if name.hasPrefix("_") {
      return false
    }
    guard let prefix = objcPrefix(ofClassName: name) else {
      return true
    }
    return !superwallPrefixes.contains(prefix)
  }

  /// What the Objective-C classes in `names` come down to in the SDK hash: each
  /// class's prefix, or its whole name when it has none, deduplicated and sorted
  /// by UTF-8 bytes.
  ///
  /// An SDK's classes share a prefix, so a new SDK brings a new one. A class added
  /// under a prefix that's already there, as the app's own usually are, changes
  /// nothing.
  static func objcPrefixesAndUnprefixedNames(in names: [String]) -> [String] {
    return sortedByUTF8(Set(names.map { objcPrefix(ofClassName: $0) ?? $0 }))
  }

  /// Sorted by UTF-8 bytes rather than `String`'s order, which follows Unicode rules
  /// that could change between OS versions and move the SDK hash.
  static func sortedByUTF8<Names: Sequence>(_ names: Names) -> [String] where Names.Element == String {
    return names.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
  }

  /// The module a Swift class is declared in, from its Objective-C runtime name.
  ///
  /// The runtime gives most Swift classes as `Module.Name`. Classes that are
  /// private or nested in a private or local type keep the mangled form: `_Tt`, a
  /// letter for each context the class is in (`C` class, `V` struct, `O` enum, `F`
  /// function and so on), then the module's length and name, as in
  /// `_TtC11PhotoFilterP33_…`, `_TtCCC15CIFilterFactory4CIFF…` or
  /// `_TtCFIZvC5Kanna12CloudSession…`. `s` and `So` stand in for the standard
  /// library and imported Objective-C. Objective-C names never contain a dot, and a
  /// Swift class renamed with `@objc(Name)` has no module.
  static func swiftModule(ofClassName name: String) -> String? {
    let utf8 = Array(name.utf8)
    guard utf8.starts(with: "_Tt".utf8) else {
      guard let dot = utf8.firstIndex(of: UInt8(ascii: ".")),
        dot > 0 else {
        return nil
      }
      return String(bytes: utf8[0..<dot], encoding: .utf8)
    }

    var index = 3
    while index < utf8.count, isLetter(utf8[index]) {
      index += 1
    }
    let contexts = utf8[3..<index]
    if contexts.last == UInt8(ascii: "s") {
      return "Swift"
    }
    if contexts.suffix(2).elementsEqual("So".utf8) {
      return "__C"
    }

    var length = 0
    while index < utf8.count, isDigit(utf8[index]) {
      length = length * 10 + Int(utf8[index] - UInt8(ascii: "0"))
      // A module's name can't be longer than the class name it's part of. Checked
      // on every digit, so a long run of them can't overflow.
      if length > utf8.count {
        return nil
      }
      index += 1
    }
    guard
      length > 0,
      index + length <= utf8.count
    else {
      return nil
    }
    return String(bytes: utf8[index..<index + length], encoding: .utf8)
  }

  /// The capitals before the one that starts an Objective-C class's first word:
  /// `GUL` for `GULAppDelegateSwizzler`, `NS` for `NSURLSessionTask`.
  ///
  /// Names with fewer than two leading capitals, such as `Branch`, have none.
  static func objcPrefix(ofClassName name: String) -> String? {
    let utf8 = Array(name.utf8)
    var count = 0
    while count < utf8.count, isUppercase(utf8[count]) {
      count += 1
    }
    guard
      count >= 3,
      count < utf8.count,
      isLowercase(utf8[count])
    else {
      return nil
    }
    return String(bytes: utf8[0..<count - 1], encoding: .utf8)
  }

  /// The modules the app's own code could be in, from its Info.plist.
  ///
  /// Xcode names the module after the product, which is usually the executable's
  /// name and the bundle's name too. A project can rename any of the three, so
  /// both names count, along with the module of any class the Info.plist names,
  /// such as the scene delegate's `MyApp.SceneDelegate`.
  static func mainModuleNames(infoDictionary: [String: Any]) -> Set<String> {
    var modules = Set(
      ["CFBundleExecutable", "CFBundleName"]
        .compactMap { infoDictionary[$0] as? String }
        .map(mainModuleName(executableName:))
    )
    modules.formUnion(modulesOfClassNames(in: infoDictionary))
    return modules
  }

  /// The modules of the Swift classes named under keys such as
  /// `UISceneDelegateClassName` and `NSExtensionPrincipalClass`.
  private static func modulesOfClassNames(in value: Any) -> Set<String> {
    if let array = value as? [Any] {
      return array.reduce(into: []) { $0.formUnion(modulesOfClassNames(in: $1)) }
    }
    guard let dictionary = value as? [String: Any] else {
      return []
    }
    var modules: Set<String> = []
    for (key, child) in dictionary {
      if let className = child as? String {
        let isClassKey = key.hasSuffix("ClassName") || key.hasSuffix("PrincipalClass")
        if isClassKey,
          let dot = className.firstIndex(of: "."),
          dot != className.startIndex {
          modules.insert(String(className[..<dot]))
        }
      } else {
        modules.formUnion(modulesOfClassNames(in: child))
      }
    }
    return modules
  }

  /// The module Xcode gives the app's own code: the executable's name, made a valid
  /// identifier.
  static func mainModuleName(executableName: String) -> String {
    var name = String(
      executableName.unicodeScalars.map { scalar -> Character in
        let isIdentifier = CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
        return isIdentifier ? Character(scalar) : "_"
      }
    )
    if name.first?.isNumber == true {
      name = "_" + name
    }
    return name
  }

  private static func isLetter(_ byte: UInt8) -> Bool {
    return isUppercase(byte) || isLowercase(byte)
  }

  private static func isUppercase(_ byte: UInt8) -> Bool {
    return byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")
  }

  private static func isLowercase(_ byte: UInt8) -> Bool {
    return byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z")
  }

  private static func isDigit(_ byte: UInt8) -> Bool {
    return byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
  }
}
