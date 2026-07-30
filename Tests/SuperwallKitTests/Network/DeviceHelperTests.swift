//
//  File.swift
//
//
//  Created by Yusuf Tör on 15/09/2023.
//
// swiftlint:disable all

import Testing
import Combine
import UIKit
@testable import SuperwallKit

struct DeviceHelperTests {
  @Test func makePaddedSdkVersion_withBeta() {
    let version = "3.0.0-beta.1"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.000.000-beta.001")
  }

  @Test func makePaddedSdkVersion_patchVersion() {
    let version = "3.0.1"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.000.001")
  }

  @Test func makePaddedSdkVersion_minorVersion() {
    let version = "3.1.1"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.001.001")
  }

  @Test func makePaddedSdkVersion_biggerMinorVersion() {
    let version = "3.10.1"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.010.001")
  }

  @Test func makePaddedSdkVersion_rc() {
    let version = "3.10.1-rc.30"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.010.001-rc.030")
  }

  @Test func makePaddedSdkVersion_limit() {
    let version = "312.123.123-rc.310"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "312.123.123-rc.310")
  }

  @Test func makePaddedSdkVersion_twoComponents() {
    let version = "3.0"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.000")
  }

  @Test func makePaddedSdkVersion_oneComponents() {
    let version = "3"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003")
  }

  // These tokens are a backend/audience-filter contract and must not change.
  @Test func contentSizeCategoryToken_mapsEveryCategory() {
    #expect(DeviceHelper.contentSizeCategoryToken(for: .extraSmall) == "xSmall")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .small) == "small")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .medium) == "medium")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .large) == "large")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .extraLarge) == "xLarge")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .extraExtraLarge) == "xxLarge")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .extraExtraExtraLarge) == "xxxLarge")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .accessibilityMedium) == "accessibilityMedium")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .accessibilityLarge) == "accessibilityLarge")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .accessibilityExtraLarge) == "accessibilityXLarge")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .accessibilityExtraExtraLarge) == "accessibilityXXLarge")
    #expect(DeviceHelper.contentSizeCategoryToken(for: .accessibilityExtraExtraExtraLarge) == "accessibilityXXXLarge")
  }

  @Test func contentSizeCategoryToken_unknownCategoryIsUnspecified() {
    #expect(DeviceHelper.contentSizeCategoryToken(for: .unspecified) == "unspecified")
    #expect(DeviceHelper.contentSizeCategoryToken(for: UIContentSizeCategory(rawValue: "someUnknownValue")) == "unspecified")
  }

  // These tokens are a backend/audience-filter contract and must not change.
  @Test func interfaceStyleToken_mapsEveryStyle() {
    #expect(DeviceHelper.interfaceStyleToken(for: .unspecified) == "Unspecified")
    #expect(DeviceHelper.interfaceStyleToken(for: .light) == "Light")
    #expect(DeviceHelper.interfaceStyleToken(for: .dark) == "Dark")
    #expect(DeviceHelper.interfaceStyleToken(for: UIUserInterfaceStyle(rawValue: 99)!) == "Unknown")
  }

  /// Reading these used to touch main-thread-only UIKit APIs, tripping
  /// "UIApplication.preferredContentSizeCategory must be used from main thread only"
  /// when the device template was built on a background thread.
  @Test func traits_areReadableOffTheMainThread() async {
    let dependencyContainer = DependencyContainer()
    let deviceHelper: DeviceHelper = dependencyContainer.deviceHelper

    let traits = await Task.detached { () -> (isMainThread: Bool, interfaceStyle: String, fontSize: Int, fontScale: Double, contentSizeCategory: String) in
      return (
        Thread.isMainThread,
        deviceHelper.interfaceStyle,
        deviceHelper.fontSize,
        deviceHelper.fontScale,
        deviceHelper.preferredContentSizeCategory
      )
    }.value

    #expect(traits.isMainThread == false)
    #expect(traits.interfaceStyle.isEmpty == false)
    #expect(traits.fontSize > 0)
    #expect(traits.fontScale > 0)
    #expect(traits.contentSizeCategory.isEmpty == false)
  }

  /// The cached traits must hold the device's real values, not placeholders.
  @MainActor
  @Test func traits_matchTheCurrentTraitValues() {
    let dependencyContainer = DependencyContainer()
    let deviceHelper: DeviceHelper = dependencyContainer.deviceHelper
    let category = UIApplication.sharedApplication?.preferredContentSizeCategory
      ?? UIScreen.main.traitCollection.preferredContentSizeCategory

    #expect(deviceHelper.preferredContentSizeCategory == DeviceHelper.contentSizeCategoryToken(for: category))
    #expect(deviceHelper.interfaceStyle == DeviceHelper.interfaceStyleToken(for: UIScreen.main.traitCollection.userInterfaceStyle))
    let scaledValue = Double(UIFontMetrics.default.scaledValue(for: 16.0))
    let expectedScale: Double = ((scaledValue / 16.0) * 100).rounded() / 100

    #expect(deviceHelper.fontSize == Int(scaledValue.rounded()))
    #expect(deviceHelper.fontScale == expectedScale)
  }

  /// A read schedules a main-thread refresh, so an appearance change landing while
  /// the app stays active can't leave the cache reporting a stale token. The refresh
  /// must survive repeated reads rather than blanking the cache.
  @Test func traits_stayCorrectAfterRepeatedReadsTriggerRefreshes() async throws {
    let dependencyContainer = DependencyContainer()
    let deviceHelper: DeviceHelper = dependencyContainer.deviceHelper

    for _ in 0..<5 {
      _ = await Task.detached {
        (deviceHelper.interfaceStyle, deviceHelper.fontSize, deviceHelper.preferredContentSizeCategory)
      }.value
      // Let the scheduled refresh land before reading again.
      try await Task.sleep(nanoseconds: 50_000_000)
    }

    let expected = await MainActor.run { () -> (String, Int, String) in
      let category = UIApplication.sharedApplication?.preferredContentSizeCategory
        ?? UIScreen.main.traitCollection.preferredContentSizeCategory
      return (
        DeviceHelper.interfaceStyleToken(for: UIScreen.main.traitCollection.userInterfaceStyle),
        Int(UIFontMetrics.default.scaledValue(for: 16.0).rounded()),
        DeviceHelper.contentSizeCategoryToken(for: category)
      )
    }

    #expect(deviceHelper.interfaceStyle == expected.0)
    #expect(deviceHelper.fontSize == expected.1)
    #expect(deviceHelper.preferredContentSizeCategory == expected.2)
  }
}
