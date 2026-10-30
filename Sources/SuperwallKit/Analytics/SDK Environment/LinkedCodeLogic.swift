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
/// Apple's modules and classes are left out: only third-party SDKs can have an
/// integration or conflict with Superwall.
enum LinkedCodeLogic {
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
  /// Apple's Objective-C class prefixes. Matched exactly against a class's prefix,
  /// since SDKs reuse their letters: CIFilterFactory's `CIFF` isn't Core Image,
  /// PostHog's `PHG` isn't Photos. Cocoa reserves `NS` and `UI` outright, so
  /// anything starting with those is Apple's too.
  static let applePrefixes: Set<String> = [
    "AV", "CA", "CG", "CI", "CK", "CL", "CN", "EK", "GK", "HK", "LA", "MK",
    "MTL", "PK", "SK", "UN", "WK"
  ]
  private static let reservedApplePrefixes = ["NS", "UI"]

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
  static func appClassNames(bundleURL: URL) -> [String] {
    let bundlePrefixes = pathPrefixes(of: bundleURL)

    var names: [String] = []
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
      for classIndex in 0..<Int(count) {
        names.append(String(cString: classNames[classIndex]))
      }
    }
    return names
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
  /// SuperwallKit and its dependencies, and Apple's and SuperwallKit's Objective-C
  /// classes. The app's own Objective-C classes stay in: nothing in the class list
  /// reliably tells them apart from a dependency's.
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

  /// Leaves out underscored names, which are private to Apple or the toolchain,
  /// and classes with Apple's or SuperwallKit's prefix.
  static func isThirdPartyObjCClass(_ name: String) -> Bool {
    if name.hasPrefix("_") {
      return false
    }
    guard let prefix = objcPrefix(ofClassName: name) else {
      return true
    }
    return !superwallPrefixes.contains(prefix) && !isApplePrefix(prefix)
  }

  static func isApplePrefix(_ prefix: String) -> Bool {
    return applePrefixes.contains(prefix)
      || reservedApplePrefixes.contains { prefix.hasPrefix($0) }
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
  /// `GUL` for `GULAppDelegateSwizzler`, `NS` for `NSURLSessionTask`. Only used to
  /// recognise Apple's and SuperwallKit's classes.
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
