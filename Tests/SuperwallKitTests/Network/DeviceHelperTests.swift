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
  /// Scales the way `makeUITraits()` does — explicitly against the resolved category,
  /// not the ambient `UITraitCollection.current`. Computing an expectation with the
  /// implicit overload would make both sides inherit the same ambient-trait fault, so
  /// the assertion couldn't fail on it.
  @MainActor
  private static func expectedScaledValue(for category: UIContentSizeCategory) -> Double {
    return Double(
      UIFontMetrics.default.scaledValue(
        for: 16.0,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
      )
    )
  }

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
      let scaledValue = Self.expectedScaledValue(for: category)
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
    let scaledValue = Self.expectedScaledValue(for: category)
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
        Int(Self.expectedScaledValue(for: category).rounded()),
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
      let scaledValue = Self.expectedScaledValue(for: category)
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

  /// The arm that actually prevents #493 — an app bundle whose application object
  /// doesn't exist yet, i.e. `configure` from a SwiftUI `App.init`. The property
  /// can't reach it: this runner is neither an app bundle nor ever gets an
  /// application, so drive the decision through the parameterised overload. Without
  /// this, loosening `"app"` would leave the whole suite green.
  @Test func isUIKitReadSafe_insideAnAppBundleBeforeLaunch_defersReads() {
    #expect(
      DeviceHelper.isUIKitReadSafe(
        hasApplication: false,
        bundleURL: URL(fileURLWithPath: "/private/var/containers/Bundle/Application/Demo.app")
      ) == false
    )
  }

  /// Once `UIApplicationMain` has built the application object the accent colour is
  /// already registered, so an app bundle stops deferring.
  @Test func isUIKitReadSafe_insideAnAppBundleAfterLaunch_allowsReads() {
    #expect(
      DeviceHelper.isUIKitReadSafe(
        hasApplication: true,
        bundleURL: URL(fileURLWithPath: "/private/var/containers/Bundle/Application/Demo.app")
      )
    )
  }

  /// Processes that never run `UIApplicationMain` — app extensions, this runner —
  /// must not wait for an application that will never arrive.
  @Test func isUIKitReadSafe_outsideAnAppBundleWithoutAnApplication_allowsReads() {
    #expect(
      DeviceHelper.isUIKitReadSafe(
        hasApplication: false,
        bundleURL: URL(fileURLWithPath: "/private/var/containers/Bundle/Application/Demo.appex")
      )
    )
  }

  @Test func makeScreenMetrics_whenReadsAreAllowed_readsTheScreen() {
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

  // MARK: - Instance-level self-healing

  /// Flippable gate for the tests below, standing in for "the application doesn't
  /// exist yet" / "launch has completed".
  private final class Gate: @unchecked Sendable {
    var isOpen: Bool
    init(_ isOpen: Bool) {
      self.isOpen = isOpen
    }
  }

  /// Builds a `DeviceHelper` with an injected gate. The container is returned
  /// alongside because the helper only holds its factory `unowned`.
  private func makeDeviceHelper(
    gate: Gate
  ) -> (DeviceHelper, DependencyContainer) {
    let dependencyContainer = DependencyContainer()
    let deviceHelper = DeviceHelper(
      api: dependencyContainer.api,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      isUIKitReadSafe: { gate.isOpen }
    )
    return (deviceHelper, dependencyContainer)
  }

  private func expectedLiveValues() async -> (
    width: Int, height: Int, scale: Double, style: String, category: String
  ) {
    await MainActor.run {
      let screen = UIApplication.sharedApplication?
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?
        .screen ?? UIScreen.main
      let category = UIApplication.sharedApplication?.preferredContentSizeCategory
        ?? UIScreen.main.traitCollection.preferredContentSizeCategory
      return (
        Int(screen.bounds.width.rounded()),
        Int(screen.bounds.height.rounded()),
        Double(screen.scale),
        DeviceHelper.interfaceStyleToken(for: UIScreen.main.traitCollection.userInterfaceStyle),
        DeviceHelper.contentSizeCategoryToken(for: category)
      )
    }
  }

  /// While reads are disallowed, an instance must serve placeholders rather than
  /// touch UIKit — the pre-launch state a `configure` in a SwiftUI `App.init`
  /// puts the SDK in.
  @Test func instance_whileReadsAreDisallowed_servesPlaceholders() {
    let gate = Gate(false)
    let (deviceHelper, dependencyContainer) = makeDeviceHelper(gate: gate)
    _ = dependencyContainer

    #expect(deviceHelper.screenWidth == 0)
    #expect(deviceHelper.screenHeight == 0)
    #expect(deviceHelper.devicePixelRatio == 1.0)
    #expect(deviceHelper.interfaceStyle == "Unknown")
    #expect(deviceHelper.fontSize == 16)
    #expect(deviceHelper.preferredContentSizeCategory == "unspecified")
  }

  /// Once the gate opens, the next read must fill both caches with the device's
  /// live values — not keep serving `.placeholder`/`.unavailable`. The traits are
  /// read from off the main thread so the read exercises the blocking
  /// empty-cache branch in `refreshUITraits()`, the path `getTemplateDevice()`
  /// and the MMP match take after a too-early init.
  @Test func instance_healsOnFirstAllowedRead() async {
    let gate = Gate(false)
    let (deviceHelper, dependencyContainer) = makeDeviceHelper(gate: gate)
    _ = dependencyContainer
    #expect(deviceHelper.screenWidth == 0)
    #expect(deviceHelper.interfaceStyle == "Unknown")

    gate.isOpen = true
    let expected = await expectedLiveValues()

    let read = await Task.detached { () -> (width: Int, height: Int, scale: Double, style: String, category: String) in
      return (
        deviceHelper.screenWidth,
        deviceHelper.screenHeight,
        deviceHelper.devicePixelRatio,
        deviceHelper.interfaceStyle,
        deviceHelper.preferredContentSizeCategory
      )
    }.value

    #expect(read.width == expected.width)
    #expect(read.height == expected.height)
    #expect(read.scale == expected.scale)
    #expect(read.style == expected.style)
    #expect(read.category == expected.category)
  }

  /// The notification observer must fill both caches after a too-early init.
  /// Posted as `UIContentSizeCategory.didChangeNotification`, which shares the
  /// handler with `didBecomeActiveNotification` but doesn't wake the app-session
  /// machinery of the containers other tests hold. Closing the gate again before
  /// reading proves the values came from the notification's fill, not from the
  /// read itself.
  @MainActor
  @Test func instance_fillsCachesOnNotification() async {
    let gate = Gate(false)
    let (deviceHelper, dependencyContainer) = makeDeviceHelper(gate: gate)
    _ = dependencyContainer
    #expect(deviceHelper.screenWidth == 0)

    gate.isOpen = true
    NotificationCenter.default.post(
      name: UIContentSizeCategory.didChangeNotification,
      object: nil
    )
    // The observer's fill consults the gate when its block *runs*, not when it
    // was enqueued, so the gate has to stay open until the fill has landed.
    // `OperationQueue.main` runs one operation at a time in enqueue order, so
    // an operation added after the post can't run before the observer's block
    // — and if delivery was inline, the fill already happened. Nothing reads
    // the helper while the gate is open, so the fill stays the only possible
    // writer and closing the gate before the assertions keeps the proof.
    await withCheckedContinuation { continuation in
      OperationQueue.main.addOperation {
        continuation.resume()
      }
    }
    gate.isOpen = false

    let expected = await expectedLiveValues()
    #expect(deviceHelper.screenWidth == expected.width)
    #expect(deviceHelper.screenHeight == expected.height)
    #expect(deviceHelper.devicePixelRatio == expected.scale)
    #expect(deviceHelper.interfaceStyle == expected.style)
    #expect(deviceHelper.preferredContentSizeCategory == expected.category)
  }
}
