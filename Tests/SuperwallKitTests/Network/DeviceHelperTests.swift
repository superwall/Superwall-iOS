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

    // Compared against the live UIKit values, not just non-empty: the placeholder
    // `UITraits.unavailable` would satisfy any weaker assertion.
    let expected = await MainActor.run { () -> (String, Int, Double, String) in
      let category = UIApplication.sharedApplication?.preferredContentSizeCategory
        ?? UIScreen.main.traitCollection.preferredContentSizeCategory
      let scaledValue = Double(UIFontMetrics.default.scaledValue(for: 16.0))
      return (
        DeviceHelper.interfaceStyleToken(for: UIScreen.main.traitCollection.userInterfaceStyle),
        Int(scaledValue.rounded()),
        ((scaledValue / 16.0) * 100).rounded() / 100,
        DeviceHelper.contentSizeCategoryToken(for: category)
      )
    }

    #expect(traits.isMainThread == false)
    #expect(traits.interfaceStyle == expected.0)
    #expect(traits.fontSize == expected.1)
    #expect(traits.fontScale == expected.2)
    #expect(traits.contentSizeCategory == expected.3)
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

  /// Every read schedules a main-thread write to the cache, so a fault in the
  /// refresh-on-read backstop would leave the cache blanked or stale rather than
  /// holding the device's real values. Nothing here can change the device's traits,
  /// so this pins that the writes keep the cache correct, not that a flip is picked
  /// up — no in-process way exists to move `UIScreen.main`'s trait collection.
  @Test func traits_stayCorrectAfterRepeatedReadsTriggerRefreshes() async {
    let dependencyContainer = DependencyContainer()
    let deviceHelper: DeviceHelper = dependencyContainer.deviceHelper

    for _ in 0..<5 {
      _ = await Task.detached {
        (deviceHelper.interfaceStyle, deviceHelper.fontSize, deviceHelper.preferredContentSizeCategory)
      }.value
      // The refresh is enqueued on the main queue before this hop, so hopping to the
      // main actor drains it deterministically instead of sleeping on it.
      await MainActor.run {}
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

  /// Taking the four trait fields from one `currentUITraits` snapshot inlined the
  /// `interfaceStyleOverride` short-circuit that the `interfaceStyle` property used
  /// to apply, so pin that the override still wins and the other three fields still
  /// come from the device.
  ///
  /// The snapshot itself isn't pinned here — nothing observable distinguishes one
  /// read from four, since `makeUITraits()`'s hop count can't be counted from a
  /// test. That property rests on the comments at both call sites.
  @Test func templateDevice_keepsTheInterfaceStyleOverrideAndFillsTheRestFromTheDevice() async {
    let dependencyContainer = DependencyContainer()
    let deviceHelper: DeviceHelper = dependencyContainer.deviceHelper

    let expected = await MainActor.run { () -> (style: String, fontSize: Int, fontScale: Double, category: String) in
      let category = UIApplication.sharedApplication?.preferredContentSizeCategory
        ?? UIScreen.main.traitCollection.preferredContentSizeCategory
      let scaledValue = Double(UIFontMetrics.default.scaledValue(for: 16.0))
      return (
        DeviceHelper.interfaceStyleToken(for: UIScreen.main.traitCollection.userInterfaceStyle),
        Int(scaledValue.rounded()),
        ((scaledValue / 16.0) * 100).rounded() / 100,
        DeviceHelper.contentSizeCategoryToken(for: category)
      )
    }

    // No override: every field mirrors the device.
    let template = await deviceHelper.getTemplateDevice()
    #expect(template["interfaceStyle"] as? String == expected.style)
    // The template resolves the override by hand instead of going through
    // `interfaceStyle`, which is what `X-Device-Interface-Style` uses. Pin that the
    // two agree so the duplicated precedence rule can't drift silently.
    #expect(template["interfaceStyle"] as? String == deviceHelper.interfaceStyle)
    #expect(template["fontSize"] as? Int == expected.fontSize)
    // Cast both sides to `Double`: comparing against the `[String: Any]` value
    // directly can resolve to SwiftyJSON's `NSNumber ==`.
    #expect(template["fontScale"] as? Double == Double(expected.fontScale))
    #expect(template["preferredContentSizeCategory"] as? String == expected.category)

    // Override set: it wins for `interfaceStyle` alone, and the snapshot still
    // supplies the other three.
    deviceHelper.interfaceStyleOverride = .dark
    let overridden = await deviceHelper.getTemplateDevice()
    #expect(overridden["interfaceStyle"] as? String == "Dark")
    #expect(overridden["interfaceStyle"] as? String == deviceHelper.interfaceStyle)
    #expect(overridden["interfaceStyleMode"] as? String == "manual")
    #expect(overridden["fontSize"] as? Int == expected.fontSize)
    #expect(overridden["fontScale"] as? Double == Double(expected.fontScale))
    #expect(overridden["preferredContentSizeCategory"] as? String == expected.category)

    deviceHelper.interfaceStyleOverride = nil
  }

  /// `configure` from a SwiftUI `App.init` runs before `UIApplicationMain` has
  /// created the application object. Touching `UIScreen` or `UIFontMetrics` at
  /// that point makes UIKit build its trait system before the app's accent color
  /// is registered, permanently resetting the global tint to system blue (#493).
  /// Both readers must return nothing rather than touch UIKit; the flag is
  /// injected because the pre-launch state can't be recreated in-process.
  @Test func makeScreenMetrics_beforeTheApplicationExists_readsNothing() {
    #expect(DeviceHelper.makeScreenMetrics(isUIKitReadSafe: { false }) == nil)
  }

  @Test func makeUITraits_beforeTheApplicationExists_readsNothing() {
    #expect(DeviceHelper.makeUITraits(isUIKitReadSafe: { false }) == nil)
  }

  /// This test runner has no `UIApplication` and never launches one, like an app
  /// extension. Deferring UIKit reads there would leave the device attributes as
  /// placeholders forever, so the gate must allow reads despite the missing
  /// application object.
  @Test func isUIKitReadSafe_withoutAnApplicationOutsideAnAppBundle_allowsReads() {
    #expect(DeviceHelper.isUIKitReadSafe)
  }

  @Test func makeScreenMetrics_whenTheApplicationExists_readsTheScreen() {
    let metrics = DeviceHelper.makeScreenMetrics()
    #expect((metrics?.width ?? 0) > 0)
    #expect((metrics?.height ?? 0) > 0)
    #expect((metrics?.scale ?? 0) >= 1.0)
  }

  /// The screen metrics moved from init-time `let`s to a cache so a too-early
  /// init can heal itself, so pin that reads still match the screen and stay
  /// safe off the main thread, where `matchMMPInstall` reads them.
  @Test func screenMetrics_matchTheScreenWhenReadOffTheMainThread() async {
    let dependencyContainer = DependencyContainer()
    let deviceHelper: DeviceHelper = dependencyContainer.deviceHelper

    let expected = await MainActor.run { () -> (width: Int, height: Int, scale: Double) in
      let screen = UIApplication.sharedApplication?
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?
        .screen ?? UIScreen.main
      return (
        Int(screen.bounds.width.rounded()),
        Int(screen.bounds.height.rounded()),
        Double(screen.scale)
      )
    }

    let read = await Task.detached { () -> (isMainThread: Bool, width: Int, height: Int, scale: Double) in
      return (
        Thread.isMainThread,
        deviceHelper.screenWidth,
        deviceHelper.screenHeight,
        deviceHelper.devicePixelRatio
      )
    }.value

    #expect(read.isMainThread == false)
    #expect(read.width == expected.width)
    #expect(read.height == expected.height)
    #expect(read.scale == expected.scale)
  }
}
