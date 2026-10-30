//
//  NotificationTokenLogic.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 27/10/2026.
//

import Foundation
import UserNotifications

/// The APNs environment a device token was issued for. A token only works
/// against the environment it came from.
enum ApnsEnvironment: String, Codable, Equatable {
  case sandbox = "SANDBOX"
  case production = "PRODUCTION"
}

/// The notification permission as reported to Superwall.
enum NotificationPermissionStatus: String, Codable, Equatable {
  case authorized = "AUTHORIZED"
  case provisional = "PROVISIONAL"
  case ephemeral = "EPHEMERAL"
  case denied = "DENIED"
  case notDetermined = "NOT_DETERMINED"
}

/// The parts of `UNNotificationSettings` that are reported to Superwall.
///
/// `UNNotificationSettings` can't be created outside the system, so this lets
/// the mapping be tested.
struct NotificationSettingsSnapshot: Equatable {
  var authorizationStatus: UNAuthorizationStatus
  var alertSetting: UNNotificationSetting = .notSupported
  var badgeSetting: UNNotificationSetting = .notSupported
  var soundSetting: UNNotificationSetting = .notSupported
  var carPlaySetting: UNNotificationSetting = .notSupported
  var criticalAlertSetting: UNNotificationSetting = .notSupported
  var timeSensitiveSetting: UNNotificationSetting = .notSupported
  var providesAppNotificationSettings = false
}

extension NotificationSettingsSnapshot {
  init(_ settings: UNNotificationSettings) {
    authorizationStatus = settings.authorizationStatus
    alertSetting = settings.alertSetting
    soundSetting = settings.soundSetting
    criticalAlertSetting = settings.criticalAlertSetting
    timeSensitiveSetting = settings.timeSensitiveSetting
    #if !os(watchOS)
      badgeSetting = settings.badgeSetting
      providesAppNotificationSettings = settings.providesAppNotificationSettings
    #endif
    #if os(iOS) && !targetEnvironment(macCatalyst)
      carPlaySetting = settings.carPlaySetting
    #endif
  }
}

/// The contents of a `notification_token` event.
struct NotificationTokenPayload: Equatable {
  /// The lowercase hex of the APNs device token.
  let address: String
  let apnsEnvironment: ApnsEnvironment
  let apnsTopic: String
  let authorizationOptions: Int
  let permissionStatus: NotificationPermissionStatus
  let enabled: Bool
  let appVersion: String
  let sdkVersion: String

  /// The event's parameters, keyed exactly as the server reads them.
  var parameters: [String: Any] {
    return [
      "channel": "apns",
      "address": address,
      "apnsEnvironment": apnsEnvironment.rawValue,
      "apnsTopic": apnsTopic,
      "authorizationOptions": authorizationOptions,
      "permissionStatus": permissionStatus.rawValue,
      "enabled": enabled,
      "appVersion": appVersion,
      "sdkVersion": sdkVersion
    ]
  }
}

enum NotificationTokenLogic {
  /// `UNAuthorizationOptions` raw bits, spelled out because they're part of
  /// the wire contract and `timeSensitive` is deprecated in the SDK headers.
  enum AuthorizationOptionBit {
    static let badge = 1
    static let sound = 2
    static let alert = 4
    static let carPlay = 8
    static let criticalAlert = 16
    static let providesAppNotificationSettings = 32
    static let provisional = 64
    static let timeSensitive = 256
  }

  /// Lowercase hex of the token's bytes, the form APNs expects.
  static func hexString(from deviceToken: Data) -> String {
    return deviceToken.map { String(format: "%02x", $0) }.joined()
  }

  /// The options the user has granted, as a `UNAuthorizationOptions` bitmask.
  static func authorizationOptions(from settings: NotificationSettingsSnapshot) -> Int {
    var options = 0
    if settings.badgeSetting == .enabled {
      options |= AuthorizationOptionBit.badge
    }
    if settings.soundSetting == .enabled {
      options |= AuthorizationOptionBit.sound
    }
    if settings.alertSetting == .enabled {
      options |= AuthorizationOptionBit.alert
    }
    if settings.carPlaySetting == .enabled {
      options |= AuthorizationOptionBit.carPlay
    }
    if settings.criticalAlertSetting == .enabled {
      options |= AuthorizationOptionBit.criticalAlert
    }
    if settings.providesAppNotificationSettings {
      options |= AuthorizationOptionBit.providesAppNotificationSettings
    }
    if settings.authorizationStatus == .provisional {
      options |= AuthorizationOptionBit.provisional
    }
    if settings.timeSensitiveSetting == .enabled {
      options |= AuthorizationOptionBit.timeSensitive
    }
    return options
  }

  static func permissionStatus(from status: UNAuthorizationStatus) -> NotificationPermissionStatus {
    switch status {
    case .authorized:
      return .authorized
    case .provisional:
      return .provisional
    case .ephemeral:
      return .ephemeral
    case .denied:
      return .denied
    case .notDetermined:
      return .notDetermined
    @unknown default:
      return .notDetermined
    }
  }

  /// Works out which APNs environment the app's tokens belong to.
  ///
  /// App Store and TestFlight builds don't embed a provisioning profile and
  /// always get production tokens. Development and ad hoc builds embed one,
  /// whose `aps-environment` entitlement says which environment it is. The
  /// profile is a CMS-signed message wrapping a plist, so the plist is found
  /// by scanning its bytes rather than by verifying the signature.
  ///
  /// - Parameters:
  ///   - profile: The contents of `embedded.mobileprovision`, if there is one.
  ///   - isSimulator: Whether the app is running in a simulator, whose tokens
  ///     are always sandbox tokens.
  static func apnsEnvironment(
    fromProvisioningProfile profile: Data?,
    isSimulator: Bool
  ) -> ApnsEnvironment {
    guard let profile = profile else {
      return isSimulator ? .sandbox : .production
    }
    if isSimulator {
      return .sandbox
    }
    guard let plist = provisioningProfilePlist(from: profile) else {
      return .production
    }

    let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
    // iOS uses `aps-environment`, macOS `com.apple.developer.aps-environment`.
    let environment = entitlements["aps-environment"] as? String
      ?? entitlements["com.apple.developer.aps-environment"] as? String

    switch environment {
    case "development":
      return .sandbox
    case "production":
      return .production
    default:
      // Without the entitlement the app can't get a token at all. Fall back
      // on whether this is a debuggable (development) build.
      let isDebuggable = entitlements["get-task-allow"] as? Bool ?? false
      return isDebuggable ? .sandbox : .production
    }
  }

  /// Extracts the plist embedded in a CMS-signed provisioning profile.
  static func provisioningProfilePlist(from profile: Data) -> [String: Any]? {
    guard
      let start = profile.range(of: Data("<?xml".utf8))
        ?? profile.range(of: Data("<plist".utf8)),
      let end = profile.range(
        of: Data("</plist>".utf8),
        in: start.lowerBound..<profile.endIndex
      )
    else {
      return nil
    }
    let plistData = profile.subdata(in: start.lowerBound..<end.upperBound)
    let plist = try? PropertyListSerialization.propertyList(
      from: plistData,
      options: [],
      format: nil
    )
    return plist as? [String: Any]
  }

  /// The contents of the app's embedded provisioning profile, if it has one.
  static func embeddedProvisioningProfile(in bundle: Bundle = .main) -> Data? {
    let urls = [
      bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
      // macOS and Mac Catalyst apps keep it at `Contents/embedded.provisionprofile`.
      bundle.bundleURL.appendingPathComponent("Contents/embedded.provisionprofile")
    ]
    for case let url? in urls {
      if let data = try? Data(contentsOf: url) {
        return data
      }
    }
    return nil
  }

  /// The APNs environment of this app's tokens, worked out once per launch.
  static let currentApnsEnvironment: ApnsEnvironment = {
    #if targetEnvironment(simulator)
      let isSimulator = true
    #else
      let isSimulator = false
    #endif
    return apnsEnvironment(
      fromProvisioningProfile: embeddedProvisioningProfile(),
      isSimulator: isSimulator
    )
  }()

  /// The Superwall send a notification belongs to, read from the top-level
  /// `sw` dictionary of its payload: `{ "sw": { "sendId": "…", "cpId": "…" } }`.
  ///
  /// Returns `nil` for notifications Superwall didn't send.
  static func notificationOpen(
    fromUserInfo userInfo: [AnyHashable: Any]
  ) -> PrivateSuperwallEvents.NotificationOpen? {
    guard
      let superwall = userInfo["sw"] as? [String: Any],
      let sendId = superwall["sendId"] as? String,
      !sendId.isEmpty
    else {
      return nil
    }
    return PrivateSuperwallEvents.NotificationOpen(
      sendId: sendId,
      contactPointId: superwall["cpId"] as? String
    )
  }
}
