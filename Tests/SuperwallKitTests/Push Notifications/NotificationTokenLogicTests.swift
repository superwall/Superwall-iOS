//
//  NotificationTokenLogicTests.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 27/10/2026.
//
// swiftlint:disable all

import Testing
import Foundation
import UserNotifications
@testable import SuperwallKit

struct NotificationTokenLogicTests {
  // MARK: - Hex encoding

  @Test func hexString_isLowercaseAndZeroPadded() {
    let token = Data([0x00, 0x0a, 0xab, 0x10, 0xff, 0x7f])
    #expect(NotificationTokenLogic.hexString(from: token) == "000aab10ff7f")
  }

  @Test func hexString_fullLengthToken() {
    let token = Data((0..<32).map { UInt8($0 * 8) })
    let hex = NotificationTokenLogic.hexString(from: token)
    #expect(hex.count == 64)
    #expect(hex.hasPrefix("00081018"))
    #expect(hex == hex.lowercased())
  }

  @Test func hexString_empty() {
    #expect(NotificationTokenLogic.hexString(from: Data()).isEmpty)
  }

  // MARK: - APNs environment

  @Test func environment_developmentProfile_isSandbox() {
    let profile = ProvisioningProfileFixture.make(apsEnvironment: "development")
    #expect(
      NotificationTokenLogic.apnsEnvironment(fromProvisioningProfile: profile, isSimulator: false)
        == .sandbox
    )
  }

  @Test func environment_productionProfile_isProduction() {
    let profile = ProvisioningProfileFixture.make(apsEnvironment: "production")
    #expect(
      NotificationTokenLogic.apnsEnvironment(fromProvisioningProfile: profile, isSimulator: false)
        == .production
    )
  }

  @Test func environment_macOSEntitlementKey() {
    let profile = ProvisioningProfileFixture.make(
      apsEnvironment: "development",
      apsKey: "com.apple.developer.aps-environment"
    )
    #expect(
      NotificationTokenLogic.apnsEnvironment(fromProvisioningProfile: profile, isSimulator: false)
        == .sandbox
    )
  }

  @Test func environment_noProfile_isProduction() {
    // App Store and TestFlight builds don't embed a profile.
    #expect(
      NotificationTokenLogic.apnsEnvironment(fromProvisioningProfile: nil, isSimulator: false)
        == .production
    )
  }

  @Test func environment_noProfileInSimulator_isSandbox() {
    #expect(
      NotificationTokenLogic.apnsEnvironment(fromProvisioningProfile: nil, isSimulator: true)
        == .sandbox
    )
  }

  @Test func environment_profileWithoutApsEntitlement_fallsBackOnGetTaskAllow() {
    let debuggable = ProvisioningProfileFixture.make(apsEnvironment: nil, getTaskAllow: true)
    let release = ProvisioningProfileFixture.make(apsEnvironment: nil, getTaskAllow: false)
    #expect(
      NotificationTokenLogic.apnsEnvironment(fromProvisioningProfile: debuggable, isSimulator: false)
        == .sandbox
    )
    #expect(
      NotificationTokenLogic.apnsEnvironment(fromProvisioningProfile: release, isSimulator: false)
        == .production
    )
  }

  @Test func environment_unparseableProfile_isProduction() {
    let garbage = Data([0x30, 0x82, 0x01, 0x02, 0x06, 0x09])
    #expect(
      NotificationTokenLogic.apnsEnvironment(fromProvisioningProfile: garbage, isSimulator: false)
        == .production
    )
  }

  @Test func provisioningProfilePlist_ignoresSurroundingSignatureBytes() {
    let profile = ProvisioningProfileFixture.make(apsEnvironment: "development")
    let plist = NotificationTokenLogic.provisioningProfilePlist(from: profile)
    #expect(plist?["Name"] as? String == "Fixture Profile")
  }

  // MARK: - Authorization options

  @Test func authorizationOptions_mapsEachEnabledSettingToItsBit() {
    let settings = NotificationSettingsSnapshot(
      authorizationStatus: .authorized,
      alertSetting: .enabled,
      badgeSetting: .enabled,
      soundSetting: .enabled,
      carPlaySetting: .enabled,
      criticalAlertSetting: .enabled,
      timeSensitiveSetting: .enabled,
      providesAppNotificationSettings: true
    )
    // 1 + 2 + 4 + 8 + 16 + 32 + 256
    #expect(NotificationTokenLogic.authorizationOptions(from: settings) == 319)
  }

  @Test func authorizationOptions_ignoresDisabledAndUnsupportedSettings() {
    let settings = NotificationSettingsSnapshot(
      authorizationStatus: .authorized,
      alertSetting: .enabled,
      badgeSetting: .disabled,
      soundSetting: .enabled,
      carPlaySetting: .notSupported,
      criticalAlertSetting: .disabled,
      timeSensitiveSetting: .disabled
    )
    #expect(NotificationTokenLogic.authorizationOptions(from: settings) == 4 | 2)
  }

  @Test func authorizationOptions_provisionalComesFromStatus() {
    let settings = NotificationSettingsSnapshot(
      authorizationStatus: .provisional,
      alertSetting: .enabled
    )
    #expect(NotificationTokenLogic.authorizationOptions(from: settings) == 4 | 64)
  }

  @Test func authorizationOptions_timeSensitiveOnly() {
    let settings = NotificationSettingsSnapshot(
      authorizationStatus: .authorized,
      timeSensitiveSetting: .enabled
    )
    #expect(NotificationTokenLogic.authorizationOptions(from: settings) == 256)
  }

  @Test func authorizationOptions_denied_isZero() {
    let settings = NotificationSettingsSnapshot(
      authorizationStatus: .denied,
      alertSetting: .disabled,
      badgeSetting: .disabled,
      soundSetting: .disabled
    )
    #expect(NotificationTokenLogic.authorizationOptions(from: settings) == 0)
  }

  @Test func authorizationOptionBits_matchUNAuthorizationOptions() {
    #expect(NotificationTokenLogic.AuthorizationOptionBit.badge == Int(UNAuthorizationOptions.badge.rawValue))
    #expect(NotificationTokenLogic.AuthorizationOptionBit.sound == Int(UNAuthorizationOptions.sound.rawValue))
    #expect(NotificationTokenLogic.AuthorizationOptionBit.alert == Int(UNAuthorizationOptions.alert.rawValue))
    #expect(NotificationTokenLogic.AuthorizationOptionBit.carPlay == Int(UNAuthorizationOptions.carPlay.rawValue))
    #expect(
      NotificationTokenLogic.AuthorizationOptionBit.criticalAlert
        == Int(UNAuthorizationOptions.criticalAlert.rawValue)
    )
    #expect(
      NotificationTokenLogic.AuthorizationOptionBit.providesAppNotificationSettings
        == Int(UNAuthorizationOptions.providesAppNotificationSettings.rawValue)
    )
    #expect(
      NotificationTokenLogic.AuthorizationOptionBit.provisional
        == Int(UNAuthorizationOptions.provisional.rawValue)
    )
  }

  // MARK: - Permission status

  @Test(arguments: [
    (UNAuthorizationStatus.authorized, "AUTHORIZED"),
    (.provisional, "PROVISIONAL"),
    (.ephemeral, "EPHEMERAL"),
    (.denied, "DENIED"),
    (.notDetermined, "NOT_DETERMINED")
  ])
  func permissionStatus(status: UNAuthorizationStatus, expected: String) {
    #expect(NotificationTokenLogic.permissionStatus(from: status).rawValue == expected)
  }

  // MARK: - Notification open

  @Test func notificationOpen_readsSendAndContactPoint() {
    let userInfo: [AnyHashable: Any] = [
      "aps": ["alert": "Hello"],
      "sw": ["sendId": "send_123", "cpId": "cp_456"]
    ]
    let event = NotificationTokenLogic.notificationOpen(fromUserInfo: userInfo)
    #expect(event?.sendId == "send_123")
    #expect(event?.contactPointId == "cp_456")
    #expect(event?.rawName == "notification_open")
    #expect(event?.audienceFilterParams["sendId"] as? String == "send_123")
    #expect(event?.audienceFilterParams["contactPointId"] as? String == "cp_456")
  }

  @Test func notificationOpen_withoutSw_isIgnored() {
    let userInfo: [AnyHashable: Any] = ["aps": ["alert": "Not from Superwall"]]
    #expect(NotificationTokenLogic.notificationOpen(fromUserInfo: userInfo) == nil)
  }

  @Test func notificationOpen_swWithoutSendId_isIgnored() {
    let userInfo: [AnyHashable: Any] = ["sw": ["cpId": "cp_456"]]
    #expect(NotificationTokenLogic.notificationOpen(fromUserInfo: userInfo) == nil)
  }

  @Test func notificationOpen_withoutContactPoint() {
    let userInfo: [AnyHashable: Any] = ["sw": ["sendId": "send_123"]]
    let event = NotificationTokenLogic.notificationOpen(fromUserInfo: userInfo)
    #expect(event?.sendId == "send_123")
    #expect(event?.contactPointId == nil)
    #expect(event?.audienceFilterParams["contactPointId"] == nil)
  }
}

/// Builds data shaped like an `embedded.mobileprovision`: a plist wrapped in
/// CMS signature bytes.
enum ProvisioningProfileFixture {
  static func make(
    apsEnvironment: String?,
    apsKey: String = "aps-environment",
    getTaskAllow: Bool = true
  ) -> Data {
    var entitlements: [String: Any] = [
      "application-identifier": "TEAMID.com.example.app",
      "get-task-allow": getTaskAllow
    ]
    if let apsEnvironment = apsEnvironment {
      entitlements[apsKey] = apsEnvironment
    }
    let plist: [String: Any] = [
      "Name": "Fixture Profile",
      "TeamIdentifier": ["TEAMID"],
      "Entitlements": entitlements
    ]
    let plistData = try! PropertyListSerialization.data(
      fromPropertyList: plist,
      format: .xml,
      options: 0
    )
    // DER-ish prefix and suffix, including bytes that aren't valid UTF-8.
    let prefix = Data([0x30, 0x82, 0x3b, 0x1c, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x02, 0xa0])
    let suffix = Data([0xa0, 0x82, 0x0d, 0x45, 0x30, 0x82, 0x04, 0x34, 0xff, 0xfe, 0x00])
    return prefix + plistData + suffix
  }
}
