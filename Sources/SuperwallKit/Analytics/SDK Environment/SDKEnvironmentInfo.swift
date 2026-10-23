//
//  SDKEnvironmentInfo.swift
//  SuperwallKit
//
//  Created by Jake Mor on 23/10/2026.
//

import Foundation

/// The third-party SDKs the app includes, and the toolchain it was built with.
/// Sent with ``PrivateSuperwallEvent/SDKEnvironment`` on app open when the SDKs
/// have changed.
///
/// It's collected for two things only: so the dashboard can suggest the Superwall
/// integration for an SDK the app already ships, and so support can see whether an
/// SDK known to conflict with Superwall is present when a bug is reported. It
/// describes the app's binary, which is the same for everyone running a build, and
/// holds nothing about the person using the app.
///
/// Names go up only as hashes (see `SDKEnvironmentLogic.nameHash`), since any of
/// them can be one of the developer's own. Superwall matches them against the
/// hashes of the SDKs it knows.
struct SDKEnvironmentInfo: Equatable {
  /// A `.framework` or `.bundle` inside the app.
  struct EmbeddedBundle: Equatable {
    /// The directory's name without its extension, such as `AppsFlyerLib`.
    let name: String
    let bundleId: String?
    /// `CFBundleShortVersionString`. Often missing, or a template's placeholder
    /// `1.0`, because SDK vendors don't all fill it in.
    let version: String?
  }

  /// A list of names, sent as their hashes.
  struct NameHashes: Equatable {
    static let encoding = "sha256-64+base64"

    /// The names' 8-byte hashes, deduplicated, sorted by byte order, concatenated
    /// and base64-encoded.
    let encoded: String
    /// How many distinct names there are.
    let count: Int
    /// Whether hashes were dropped from the end to stay under the cap.
    let isTruncated: Bool
  }

  /// The Swift modules with classes in the app's own code. Leaves out the app's main
  /// module, SuperwallKit and its dependencies.
  let swiftModules: NameHashes
  /// The Objective-C class names in the app's own code.
  let objcClassNames: NameHashes
  /// The `.framework` bundles embedded in the app, without Apple's or
  /// SuperwallKit's, sorted by name and capped. Their names and bundle IDs are
  /// hashed when sent, and their versions aren't.
  let frameworks: [EmbeddedBundle]
  /// How many frameworks there were before the cap.
  let frameworkCount: Int
  /// The names of the `.bundle` resource bundles at the top of the app, without
  /// Apple's or SuperwallKit's.
  let resourceBundles: NameHashes
  /// `DTXcode`, such as `2601` for Xcode 26.0.1.
  let xcodeVersion: String?
  /// `DTSDKName`, the OS SDK the app was linked against, such as `iphoneos26.0`.
  let buildSDKName: String?
  /// `MinimumOSVersion`, or `LSMinimumSystemVersion` on Mac Catalyst.
  let minimumOSVersion: String?
  /// Whether the app can ask for App Tracking Transparency.
  let hasTrackingUsageDescription: Bool
  /// How many ad networks the app lists in `SKAdNetworkItems`.
  let skAdNetworkItemCount: Int
  /// The SHA-256 of the SDK data alone: the modules, class names, frameworks and
  /// resource bundles. The event is sent when this changes. See
  /// `SDKEnvironmentLogic.sdkHash`.
  let sdkHash: String

  // Lists go out as a string or a dictionary because event parameters drop arrays
  // (see `TrackingLogic.clean(input:)`).
  func toDictionary() -> [String: Any] {
    var dictionary: [String: Any] = [
      "sdk_environment_sha256": sdkHash,
      "name_hash_encoding": NameHashes.encoding,
      "embedded_frameworks": encodedFrameworks(),
      "embedded_framework_count": frameworkCount,
      "has_tracking_usage_description": hasTrackingUsageDescription,
      "skadnetwork_item_count": skAdNetworkItemCount
    ]
    for (key, hashes) in [
      ("swift_module", swiftModules),
      ("objc_class_name", objcClassNames),
      ("resource_bundle", resourceBundles)
    ] {
      dictionary["\(key)_hashes"] = hashes.encoded
      dictionary["\(key)_count"] = hashes.count
      dictionary["\(key)_hashes_truncated"] = hashes.isTruncated
    }
    dictionary["xcode_version"] = xcodeVersion
    dictionary["build_sdk_name"] = buildSDKName
    dictionary["minimum_os_version"] = minimumOSVersion
    return dictionary
  }

  /// Keyed by the name's hash, with the bundle ID's hash and the plain version.
  private func encodedFrameworks() -> [String: [String: String]] {
    var dictionary: [String: [String: String]] = [:]
    for framework in frameworks {
      var details: [String: String] = [:]
      details["bundle_id_hash"] = framework.bundleId.map(SDKEnvironmentLogic.encodedNameHash)
      details["version"] = framework.version
      dictionary[SDKEnvironmentLogic.encodedNameHash(framework.name)] = details
    }
    return dictionary
  }
}
