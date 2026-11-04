//
//  SDKEnvironmentCollector.swift
//  SuperwallKit
//
//  Created by Jake Mor on 23/10/2026.
//

import Foundation

/// Where ``SDKEnvironmentCollector`` looks. Tests point it at their own directories,
/// Info.plist and class names.
struct SDKEnvironmentSources {
  /// The directory holding the app's embedded `.framework` bundles.
  var frameworksDirectory: URL?
  /// The directory holding the app's resource bundles.
  var resourcesDirectory: URL?
  var infoDictionary: [String: Any]
  /// The Objective-C runtime names of the classes in the app's own code and
  /// embedded frameworks.
  var classNames: () -> [String]
  /// The modules of Apple's frameworks and Swift libraries, to leave out.
  var systemModules: () -> Set<String>

  static var live: SDKEnvironmentSources {
    let bundleURL = Bundle.main.bundleURL
    let frameworksURL = Bundle.main.privateFrameworksURL
    return SDKEnvironmentSources(
      frameworksDirectory: frameworksURL,
      // The app's root on iOS, and `Contents/Resources` on Mac Catalyst.
      resourcesDirectory: Bundle.main.resourceURL,
      infoDictionary: Bundle.main.infoDictionary ?? [:],
      classNames: {
        LinkedCodeLogic.appClassNames(bundleURL: bundleURL)
      },
      systemModules: LinkedCodeLogic.loadedSystemModules
    )
  }
}

/// Collects the ``SDKEnvironmentInfo`` once per process. A running app can't gain or
/// lose an SDK, so every later call reuses the first result.
actor SDKEnvironmentCollector {
  static let shared = SDKEnvironmentCollector(sources: .live)

  private let sources: SDKEnvironmentSources
  private var collection: Task<SDKEnvironmentInfo, Never>?

  init(sources: SDKEnvironmentSources) {
    self.sources = sources
  }

  func environment() async -> SDKEnvironmentInfo {
    if let collection = collection {
      return await collection.value
    }
    let sources = sources
    // Reading the bundles touches the disk and compressing the class names takes a
    // few milliseconds, so keep it off the main thread.
    let collection = Task.detached(priority: .utility) {
      SDKEnvironmentLogic.collect(from: sources)
    }
    self.collection = collection
    return await collection.value
  }
}

enum SDKEnvironmentLogic {
  /// Bounds the event's size: apps with more embedded bundles than this are rare.
  static let maxBundleCount = 100
  static let maxStringLength = 100
  /// The most characters an encoded list of name hashes can take: 24,576 hashes.
  /// Events go up 50 to a request as uncompressed JSON, and the collector's limits
  /// aren't documented, so this stays well below anything a request or a single
  /// event might be held to.
  static let maxEncodedNameHashesLength = 256 * 1024
  /// How many bytes of each name's SHA-256 are kept.
  static let nameHashLength = 8

  static func collect(from sources: SDKEnvironmentSources) -> SDKEnvironmentInfo {
    let frameworks = embeddedBundles(in: sources.frameworksDirectory, withExtension: "framework")
    let resourceBundles = embeddedBundles(in: sources.resourcesDirectory, withExtension: "bundle")
    let info = sources.infoDictionary
    let mainModule = (info["CFBundleExecutable"] as? String)
      .map(LinkedCodeLogic.mainModuleName(executableName:))
    let linked = LinkedCodeLogic.modulesAndObjCClassNames(
      in: sources.classNames(),
      excludedModules: Set([mainModule].compactMap { $0 }),
      systemModules: sources.systemModules()
    )

    return SDKEnvironmentInfo(
      swiftModules: nameHashes(linked.modules),
      objcClassNames: nameHashes(linked.objcClassNames),
      frameworks: Array(frameworks.prefix(maxBundleCount)),
      frameworkCount: frameworks.count,
      resourceBundles: nameHashes(resourceBundles.map(\.name)),
      xcodeVersion: string(info["DTXcode"]),
      buildSDKName: string(info["DTSDKName"]),
      minimumOSVersion: string(info["MinimumOSVersion"] ?? info["LSMinimumSystemVersion"]),
      // The key is ROT13-encoded so it never appears in the binary. See `PlistKey.tracking`.
      hasTrackingUsageDescription: info[PermissionHandler.PlistKey.tracking] != nil,
      skAdNetworkItemCount: (info["SKAdNetworkItems"] as? [Any])?.count ?? 0,
      sdkHash: sdkHash(
        modules: linked.modules,
        objcClassNames: linked.objcClassNames,
        frameworks: frameworks,
        resourceBundles: resourceBundles
      )
    )
  }

  /// The SHA-256 of the SDK data alone, over the full lists before any cap.
  ///
  /// It changes when an SDK is added, removed or upgraded, since an upgrade changes
  /// a framework's version or the classes linked in. Nothing else goes in: no app
  /// version or build, none of the build settings, and no paths, since the
  /// Simulator moves the app on every install. Each list is deduplicated and sorted
  /// by UTF-8 bytes, so the hash doesn't depend on the order things were found in.
  static func sdkHash(
    modules: [String],
    objcClassNames: [String],
    frameworks: [SDKEnvironmentInfo.EmbeddedBundle],
    resourceBundles: [SDKEnvironmentInfo.EmbeddedBundle]
  ) -> String {
    func lines(_ bundles: [SDKEnvironmentInfo.EmbeddedBundle]) -> [String] {
      return bundles.map { [$0.name, $0.bundleId ?? "", $0.version ?? ""].joined(separator: "\t") }
    }
    let sections = [
      ("swift_modules", modules),
      ("objc_class_names", objcClassNames),
      ("embedded_frameworks", lines(frameworks)),
      ("resource_bundles", lines(resourceBundles))
    ]
    let text = sections
      .map { name, entries in
        ([name] + LinkedCodeLogic.sortedByUTF8(Set(entries))).joined(separator: "\n")
      }
      .joined(separator: "\n\n")
    return sha256Hex(text)
  }

  /// The first 8 bytes of the SHA-256 of the name's UTF-8 bytes.
  ///
  /// The name is hashed exactly as collected, with no salt and no normalization:
  /// the module name for a Swift class, the runtime name for an Objective-C class,
  /// and a bundle's directory name (without `.framework` or `.bundle`) or its
  /// `CFBundleIdentifier`. Superwall's catalog of known SDKs hashes names the same
  /// way, so the two have to stay in step.
  static func nameHash(_ name: String) -> [UInt8] {
    return Array((name.sha256() ?? []).prefix(nameHashLength))
  }

  static func encodedNameHash(_ name: String) -> String {
    return Data(nameHash(name)).base64EncodedString()
  }

  /// The names' hashes, deduplicated, sorted by byte order, concatenated and
  /// base64-encoded. Above the cap, the hashes that sort last are dropped. Hashes
  /// don't compress, so they aren't.
  static func nameHashes(
    _ names: [String],
    maxEncodedLength: Int = maxEncodedNameHashesLength
  ) -> SDKEnvironmentInfo.NameHashes {
    let distinctNames = Set(names)
    let hashes = Set(distinctNames.map(nameHash))
      .sorted { $0.lexicographicallyPrecedes($1) }
    // Base64 turns every 3 bytes into 4 characters.
    let maxHashCount = maxEncodedLength / 4 * 3 / nameHashLength
    let kept = hashes.prefix(maxHashCount)
    return SDKEnvironmentInfo.NameHashes(
      encoded: Data(kept.joined()).base64EncodedString(),
      count: distinctNames.count,
      isTruncated: kept.count < hashes.count
    )
  }

  static func sha256Hex(_ string: String) -> String {
    return (string.sha256() ?? [])
      .map { String(format: "%02x", $0) }
      .joined()
  }

  /// The bundles with `pathExtension` directly inside `directory`, without Apple's
  /// or SuperwallKit's, sorted by name.
  ///
  /// Reads each bundle's Info.plist without loading its code.
  static func embeddedBundles(
    in directory: URL?,
    withExtension pathExtension: String
  ) -> [SDKEnvironmentInfo.EmbeddedBundle] {
    guard
      let directory = directory,
      let contents = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles
      )
    else {
      return []
    }

    return contents
      .filter { $0.pathExtension == pathExtension }
      .compactMap { url -> SDKEnvironmentInfo.EmbeddedBundle? in
        let info = Bundle(url: url)?.infoDictionary ?? [:]
        // Not truncated: names and bundle IDs are hashed whole.
        let bundleId = (info["CFBundleIdentifier"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let name = url.deletingPathExtension().lastPathComponent
        if isApple(bundleId: bundleId) || isSuperwall(bundleName: name) {
          return nil
        }
        return SDKEnvironmentInfo.EmbeddedBundle(
          name: name,
          bundleId: bundleId,
          version: string(info["CFBundleShortVersionString"])
        )
      }
      // Byte order, unlike a localized sort, doesn't change with the user's language.
      .sorted { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }
  }

  /// SuperwallKit's own framework when it's linked dynamically, and its resource
  /// bundle: `SuperwallKit_SuperwallKit` from Swift Package Manager, `SuperwallKit`
  /// from CocoaPods.
  static func isSuperwall(bundleName name: String) -> Bool {
    return LinkedCodeLogic.superwallModules.contains { module in
      name == module || name.hasPrefix(module + "_")
    }
  }

  /// Apple's frameworks live outside the app, except in a test host, where Xcode
  /// copies XCTest and its support frameworks into the app's Frameworks folder.
  /// Apple's embedded dylibs, such as the Swift back-deployment `libswift*`
  /// libraries, are never listed: only `.framework` and `.bundle` directories are.
  static func isApple(bundleId: String?) -> Bool {
    return bundleId?.hasPrefix("com.apple.") == true
  }

  private static func string(_ value: Any?) -> String? {
    guard
      let string = value as? String,
      !string.isEmpty
    else {
      return nil
    }
    return truncated(string)
  }

  static func truncated(_ string: String) -> String {
    return String(string.prefix(maxStringLength))
  }
}
