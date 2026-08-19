//
//  File.swift
//
//  Created by Jake Mor on 8/10/21.
//
// swiftlint:disable type_body_length file_length function_body_length

import UIKit
import Foundation
import SystemConfiguration
#if canImport(CoreTelephony)
import CoreTelephony
#endif
import StoreKit

class DeviceHelper {
  var localeIdentifier: String {
    let localeIdentifier = factory.makeLocaleIdentifier()
    return localeIdentifier ?? Locale.autoupdatingCurrent.identifier
  }

  var preferredLocaleIdentifier: String {
    guard let preferredIdentifier = Locale.preferredLanguages.first else {
      return localeIdentifier
    }
    return Locale(identifier: preferredIdentifier).identifier
  }

  @DispatchQueueBacked
  var enrichment: Enrichment?

  let appInstalledAtString: String

  private let reachability: SCNetworkReachability?
  var reachabilityFlags: SCNetworkReachabilityFlags? {
    guard let reachability = reachability else {
      return nil
    }
    var flags = SCNetworkReachabilityFlags()
    SCNetworkReachabilityGetFlags(reachability, &flags)

    return flags
  }

  let appVersion = Bundle.main.releaseVersionNumber ?? ""

  let osVersion: String = {
    let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
    return String(
      format: "%ld.%ld.%ld",
      arguments: [systemVersion.majorVersion, systemVersion.minorVersion, systemVersion.patchVersion]
    )
  }()

  let isMac: Bool = {
    var output = false
    if #available(iOS 14.0, *) {
      output = ProcessInfo.processInfo.isiOSAppOnMac
    }
    return output
  }()

  let model: String = {
    UIDevice.modelName
  }()

  let vendorId: String = {
    UIDevice.current.identifierForVendor?.uuidString ?? ""
  }()

  var languageCode: String {
    if #available(iOS 16, *) {
      return Locale.autoupdatingCurrent.language.languageCode?.identifier ?? ""
    } else {
      return Locale.autoupdatingCurrent.languageCode ?? ""
    }
  }

  var preferredLanguageCode: String {
    guard let preferredIdentifier = Locale.preferredLanguages.first else {
      return languageCode
    }
    if #available(iOS 16, *) {
      return Locale(identifier: preferredIdentifier).language.languageCode?.identifier ?? ""
    } else {
      return Locale(identifier: preferredIdentifier).languageCode ?? ""
    }
  }

  private var regionCode: String {
    if #available(iOS 16, *) {
      return Locale.autoupdatingCurrent.language.region?.identifier ?? ""
    } else {
      return Locale.autoupdatingCurrent.regionCode ?? ""
    }
  }

  var preferredRegionCode: String {
    guard let preferredIdentifier = Locale.preferredLanguages.first else {
      return regionCode
    }
    if #available(iOS 16, *) {
      return Locale(identifier: preferredIdentifier).language.region?.identifier ?? ""
    } else {
      return Locale(identifier: preferredIdentifier).regionCode ?? ""
    }
  }

  var currencyCode: String {
    Locale.autoupdatingCurrent.currencyCode ?? ""
  }

  var currencySymbol: String {
    Locale.autoupdatingCurrent.currencySymbol ?? ""
  }

  var secondsFromGMT: String {
    "\(Int(TimeZone.current.secondsFromGMT()))"
  }

  var timezoneOffsetSeconds: Int {
    TimeZone.current.secondsFromGMT()
  }

  /// Screen metrics, cached from the main thread.
  ///
  /// `UIScreen` / `UIWindowScene` are main-thread-only (and `UIScreen.main`
  /// is deprecated), but these are read from background contexts such as
  /// `matchMMPInstall`. Reading on the main thread and caching keeps those
  /// reads safe instead of touching main-thread-only UIKit off-thread.
  ///
  /// `nil` until a read is allowed to touch UIKit (see ``isUIKitReadSafe``).
  /// When the SDK is configured before `UIApplicationMain` runs, the init-time
  /// read stays empty and the cache fills on first post-launch read or on app
  /// activation instead.
  @DispatchQueueBacked
  private var screenMetrics: ScreenMetrics?

  var screenWidth: Int {
    currentScreenMetrics.width
  }

  var screenHeight: Int {
    currentScreenMetrics.height
  }

  var devicePixelRatio: Double {
    currentScreenMetrics.scale
  }

  struct ScreenMetrics {
    let width: Int
    let height: Int
    let scale: Double

    /// The values used when the screen can't be read: before the application
    /// exists, and on visionOS where there is no screen.
    static let placeholder = ScreenMetrics(width: 0, height: 0, scale: 1.0)
  }

  /// The cached metrics, filling the cache first when it's still empty.
  private var currentScreenMetrics: ScreenMetrics {
    if let cached = screenMetrics {
      return cached
    }
    guard let metrics = Self.makeScreenMetrics(isUIKitReadSafe: isUIKitReadSafe) else {
      return .placeholder
    }
    screenMetrics = metrics
    return metrics
  }

  /// Whether UIKit's screen and trait APIs can be read without side effects.
  ///
  /// In an app, touching `UIScreen`, `UIFontMetrics`, or any other
  /// appearance-adjacent UIKit API before `UIApplicationMain` has created the
  /// application object — e.g. `configure` called from a SwiftUI `App.init` —
  /// makes UIKit build its trait system before the app's asset-catalog accent
  /// color is registered, permanently resetting the global tint to system blue.
  /// Every appearance-adjacent read in this file — `UIScreen`, `UIFontMetrics`,
  /// trait collections — must sit behind this check, and the check must come
  /// first: even `UIFontMetrics.default.scaledValue(for:)` alone trips it. The
  /// unguarded `UIDevice` reads at init (`model`, `vendorId`, `interfaceType`)
  /// are exempt: they don't touch the trait system, and the sample-app repro
  /// keeps its tint with them in place.
  ///
  /// A missing application object doesn't always mean that window, though: some
  /// processes never create one (unit-test runners, app extensions) yet can read
  /// `UIScreen.main` freely, and waiting there would leave placeholder values
  /// forever. Only app bundles run `UIApplicationMain`, so the bundle type
  /// disambiguates.
  static var isUIKitReadSafe: Bool {
    return isUIKitReadSafe(
      hasApplication: UIApplication.sharedApplication != nil,
      bundleURL: Bundle.main.bundleURL
    )
  }

  /// The decision above, split from the globals it reads.
  ///
  /// Both facts come from process-wide state that a test can't stage: the runner has
  /// no application object and isn't an app bundle, so the deciding arm — an app
  /// bundle with no application yet — is unreachable through the property. Taking
  /// them as parameters lets both arms be pinned, so loosening `"app"` can't leave
  /// the suite green while re-opening the accent-color bug.
  static func isUIKitReadSafe(hasApplication: Bool, bundleURL: URL) -> Bool {
    if hasApplication {
      return true
    }
    return bundleURL.pathExtension != "app"
  }

  /// The instance's view of ``isUIKitReadSafe``, injected at init. Every
  /// instance-level cache read and refresh consults this rather than the static,
  /// so tests can hold a real instance in the pre-launch state and then release
  /// it — the static's state can't be recreated in-process.
  private let isUIKitReadSafe: () -> Bool

  /// Reads the screen metrics, or `nil` when UIKit can't be touched yet.
  ///
  /// `isUIKitReadSafe` is injectable because tests can't recreate the
  /// pre-`UIApplicationMain` state in-process; it runs inside the main-thread
  /// closure so the KVC read never happens off-thread.
  static func makeScreenMetrics(
    isUIKitReadSafe: @escaping () -> Bool = { DeviceHelper.isUIKitReadSafe }
  ) -> ScreenMetrics? {
    #if os(visionOS)
    return .placeholder
    #else
    let read = { () -> ScreenMetrics? in
      guard isUIKitReadSafe() else {
        return nil
      }
      // Prefer the connected window scene's screen; fall back to the
      // deprecated `UIScreen.main` only when no scene is attached yet.
      let screen = UIApplication.sharedApplication?
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?
        .screen ?? UIScreen.main
      let bounds = screen.bounds
      return ScreenMetrics(
        width: Int(bounds.width.rounded()),
        height: Int(bounds.height.rounded()),
        scale: Double(screen.scale)
      )
    }
    return Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
    #endif
  }

  var isFirstAppOpen: Bool {
    return !storage.didTrackFirstSession
  }

  var radioType: String {
    guard let flags = reachabilityFlags else {
      return "No Internet"
    }

    let isReachable = flags.contains(.reachable)
    let isWWAN = flags.contains(.isWWAN)

    if isReachable {
      if isWWAN {
        return "Cellular"
      } else {
        return "Wifi"
      }
    } else {
      return "No Internet"
    }
  }

  var interfaceStyleOverride: InterfaceStyle?

  /// Backs `X-Device-Interface-Style`. `getTemplateDevice()` resolves the override
  /// the same way against its own trait snapshot — change one and change the other,
  /// or the template and the header disagree on a backend-contract field.
  ///
  /// Not folded into a shared `interfaceStyle(from:)` helper on purpose: passing
  /// `currentUITraits` would evaluate it eagerly, scheduling a needless cache
  /// refresh — one per network request whenever an override is set, and a blocking
  /// fill on the first pre-launch read. The early return here avoids it.
  var interfaceStyle: String {
    if let interfaceStyleOverride = interfaceStyleOverride {
      return interfaceStyleOverride.description
    }
    return currentUITraits.interfaceStyle
  }

  var fontSize: Int {
    return currentUITraits.fontSize
  }

  var fontScale: Double {
    return currentUITraits.fontScale
  }

  var preferredContentSizeCategory: String {
    return currentUITraits.preferredContentSizeCategory
  }

  /// Trait-derived values, cached from the main thread.
  ///
  /// `UIApplication.preferredContentSizeCategory`, `UIScreen.traitCollection` and
  /// `UIFontMetrics` are main-thread-only, but these are read from background
  /// contexts such as `getTemplateDevice()`. They're read on the main thread and
  /// cached, then refreshed on trait-change notifications and on read.
  ///
  /// `nil` while a read isn't yet allowed to touch UIKit (see ``isUIKitReadSafe``),
  /// which only happens when the SDK is configured before `UIApplicationMain` runs.
  @DispatchQueueBacked
  private var uiTraits: UITraits?

  /// Set while a refresh of ``uiTraits`` is already scheduled, so a burst of reads
  /// queues one main-thread hop rather than one per read.
  @DispatchQueueBacked
  private var isRefreshingUITraits = false

  private var traitObservers: [NSObjectProtocol] = []

  /// The `UITraitChangeRegistration` from ``registerForTraitChanges()``. Typed `Any?`
  /// because the protocol is iOS 17+ and a stored property can't be gated on
  /// availability.
  private var traitChangeRegistration: Any?

  /// The scene the registration was made against, held weakly. A registration goes
  /// stale two ways: UIKit tears it down when its scene deallocates, and a
  /// multi-window host can keep the scene alive in the background while another
  /// becomes active — where trait updates are deferred, so flips the user can see
  /// never fire it. Both show up as this no longer matching the active scene.
  private weak var observedTraitScene: UIWindowScene?

  /// The current traits, served from the cache on every version.
  ///
  /// `refreshUITraits()` keeps the cache fresh: main-thread reads refresh it
  /// synchronously, off-main reads schedule one coalesced main-queue refresh —
  /// blocking only to fill an empty cache, which happens when init ran before
  /// `UIApplicationMain`.
  ///
  /// From iOS 17 the trait hook also updates the cache at the moment the appearance
  /// flips. Below 17 there is no hook, so an in-place automatic light/dark change —
  /// sunset while the app is frontmost — lands one read late via the refresh-on-read
  /// backstop. That bounded lag is accepted in exchange for not blocking a
  /// cooperative-pool thread on the main queue for every network request
  /// (`X-Device-Interface-Style`) and template build; earlier releases read live here
  /// and paid that hop each time. Text-size changes and flips made while backgrounded
  /// still land immediately via the notification observers.
  private var currentUITraits: UITraits {
    refreshUITraits()
    return uiTraits ?? .unavailable
  }

  private func refreshUITraits() {
    #if !os(visionOS)
    // The wrapper's setter and getter share one serial queue, so this write is
    // ordered ahead of `currentUITraits`' read and the caller sees it.
    if Thread.isMainThread {
      if let traits = DeviceHelper.makeUITraits(isUIKitReadSafe: isUIKitReadSafe) {
        uiTraits = traits
      }
      return
    }
    // An empty cache means init ran before `UIApplicationMain` created the
    // application. Block on the first real read — `makeUITraits()` makes the
    // main-thread hop itself — rather than scheduling it, so early off-main
    // readers don't report placeholder values.
    if uiTraits == nil {
      if let traits = DeviceHelper.makeUITraits(isUIKitReadSafe: isUIKitReadSafe) {
        uiTraits = traits
      }
      return
    }
    if $isRefreshingUITraits.testAndSetTrue() {
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      if let traits = DeviceHelper.makeUITraits(isUIKitReadSafe: self.isUIKitReadSafe) {
        self.uiTraits = traits
      }
      self.isRefreshingUITraits = false
    }
    #endif
  }

  /// Updates the cache at the moment the appearance or text size flips.
  ///
  /// There is no notification for `userInterfaceStyle`, so a system appearance
  /// change while the app stays active — automatic light/dark at sunset — reaches
  /// us only through a trait hook. Without this the cache reports the previous
  /// token to `X-Device-Interface-Style` and to audience filters until something
  /// else refreshes it.
  ///
  /// Registration needs a scene, which may not exist yet when `DeviceHelper` is
  /// created, so this also runs on activation and re-arms if the observed scene has
  /// since gone away or stopped being the active one.
  ///
  /// iOS 17+ only. Below 17 the refresh-on-read backstop and the two notification
  /// observers cover this instead, rather than injecting a view into the host's
  /// window to reach `traitCollectionDidChange`.
  private func registerForTraitChanges() {
    #if !os(visionOS)
    Task { @MainActor [weak self] in
      if #available(iOS 17.0, *) {
        self?.performTraitChangeRegistration()
      }
    }
    #endif
  }

  #if !os(visionOS)
  @available(iOS 17.0, *)
  @MainActor
  private func performTraitChangeRegistration() {
    guard let scene = UIApplication.sharedApplication?.activeWindowScene else {
      return
    }
    // Already armed against the scene that's currently active.
    if traitChangeRegistration != nil && observedTraitScene === scene {
      return
    }
    // The observed scene either died or ceded activity to this one. Moving the
    // registration rather than adding a second keeps it single: one live token,
    // fired by the scene the user is looking at.
    if let staleRegistration = traitChangeRegistration as? UITraitChangeRegistration {
      observedTraitScene?.unregisterForTraitChanges(staleRegistration)
    }
    observedTraitScene = scene
    traitChangeRegistration = scene.registerForTraitChanges(
      [UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self]
    ) { [weak self] (_: UITraitEnvironment, _: UITraitCollection) in
      guard let self = self else {
        return
      }
      if let traits = DeviceHelper.makeUITraits(isUIKitReadSafe: self.isUIKitReadSafe) {
        self.uiTraits = traits
      }
    }
  }
  #endif

  struct UITraits {
    let interfaceStyle: String
    let fontSize: Int
    let fontScale: Double
    let preferredContentSizeCategory: String

    /// The values used when UIKit traits aren't available, e.g. on visionOS.
    static let unavailable = UITraits(
      interfaceStyle: "Unknown",
      fontSize: 16,
      fontScale: 1.0,
      preferredContentSizeCategory: "unspecified"
    )
  }

  /// Reads the current traits, or `nil` when UIKit can't be touched yet.
  ///
  /// `isUIKitReadSafe` is injectable because tests can't recreate the
  /// pre-`UIApplicationMain` state in-process; it runs inside the main-thread
  /// closure so the KVC read never happens off-thread.
  static func makeUITraits(
    isUIKitReadSafe: @escaping () -> Bool = { DeviceHelper.isUIKitReadSafe }
  ) -> UITraits? {
    #if os(visionOS)
    return .unavailable
    #else
    let read = { () -> UITraits? in
      guard isUIKitReadSafe() else {
        return nil
      }
      let category = UIApplication.sharedApplication?.preferredContentSizeCategory
        ?? UIScreen.main.traitCollection.preferredContentSizeCategory
      // Scale against `category` explicitly. The implicit `scaledValue(for:)` resolves
      // against `UITraitCollection.current`, which Apple documents as undefined outside
      // a view or view-controller trait callback and stores per thread — so the two
      // font numbers could disagree with the category on the line above, which is read
      // from `UIApplication` and doesn't depend on trait context. One source, so the
      // three values in a snapshot can't contradict each other in the audience filters.
      let scaledValue = UIFontMetrics.default.scaledValue(
        for: 16.0,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
      )

      return UITraits(
        interfaceStyle: interfaceStyleToken(
          for: UIScreen.main.traitCollection.userInterfaceStyle
        ),
        fontSize: Int(scaledValue.rounded()),
        fontScale: ((Double(scaledValue) / 16.0) * 100).rounded() / 100,
        preferredContentSizeCategory: contentSizeCategoryToken(for: category)
      )
    }
    return Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
    #endif
  }

  /// Refreshes the cached traits when the user changes their text size, or when the
  /// app becomes active after an appearance change. Both notifications are posted on
  /// the main thread.
  ///
  /// Activation also retries ``registerForTraitChanges()``, since a window is more
  /// likely to exist by then than when `DeviceHelper` was created, and fills the
  /// screen-metrics cache when init ran too early to read the screen.
  private func observeUITraitChanges() {
    #if !os(visionOS)
    let names: [Notification.Name] = [
      UIContentSizeCategory.didChangeNotification,
      UIApplication.didBecomeActiveNotification
    ]
    traitObservers = names.map { name in
      NotificationCenter.default.addObserver(
        forName: name,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self = self else {
          return
        }
        if let traits = DeviceHelper.makeUITraits(isUIKitReadSafe: self.isUIKitReadSafe) {
          self.uiTraits = traits
        }
        if self.screenMetrics == nil,
          let metrics = DeviceHelper.makeScreenMetrics(isUIKitReadSafe: self.isUIKitReadSafe) {
          self.screenMetrics = metrics
        }
        self.registerForTraitChanges()
      }
    }
    #endif
  }

  /// Maps a `UIUserInterfaceStyle` to the fixed dashboard token string used by
  /// backend audience filters. These tokens are a backend contract and must not change.
  static func interfaceStyleToken(for style: UIUserInterfaceStyle) -> String {
    switch style {
    case .unspecified:
      return "Unspecified"
    case .light:
      return "Light"
    case .dark:
      return "Dark"
    default:
      return "Unknown"
    }
  }

  /// Maps a `UIContentSizeCategory` to the fixed dashboard token string used by
  /// backend audience filters. These tokens are a backend contract and must not change.
  static func contentSizeCategoryToken(for category: UIContentSizeCategory) -> String {
    switch category {
    case .extraSmall: return "xSmall"
    case .small: return "small"
    case .medium: return "medium"
    case .large: return "large"
    case .extraLarge: return "xLarge"
    case .extraExtraLarge: return "xxLarge"
    case .extraExtraExtraLarge: return "xxxLarge"
    case .accessibilityMedium: return "accessibilityMedium"
    case .accessibilityLarge: return "accessibilityLarge"
    case .accessibilityExtraLarge: return "accessibilityXLarge"
    case .accessibilityExtraExtraLarge: return "accessibilityXXLarge"
    case .accessibilityExtraExtraExtraLarge: return "accessibilityXXXLarge"
    default: return "unspecified"
    }
  }

  var platformWrapper: String?

  var platformWrapperVersion: String?

  var isLowPowerModeEnabled: String {
    return ProcessInfo.processInfo.isLowPowerModeEnabled ? "true" : "false"
  }

  let bundleId: String = {
    return Bundle.main.bundleIdentifier ?? ""
  }()

  /// Set after initialization to enable test mode sandbox override.
  var testModeManager: TestModeManager?

  /// Returns true if built for the simulator, using TestFlight, or in test mode.
  var isSandbox: String {
    if testModeManager?.isTestMode == true {
      return "true"
    }
    return Self.detectSandbox()
  }

  private static func detectSandbox() -> String {
    #if targetEnvironment(simulator)
      return "true"
    #else

    // Prefer AppTransaction.environment (iOS 16+) when available,
    // as it reliably detects sandbox for all purchase types including
    // Stripe and non-StoreKit flows.
    if let isSandbox = ReceiptManager.isSandboxEnvironment {
      return "\(isSandbox)"
    }

    guard let url = Bundle.main.appStoreReceiptURL else {
      return "false"
    }

    return "\(url.path.contains("sandboxReceipt"))"
    #endif
  }

  /// The first URL scheme defined in the Info.plist. Assumes there's only one.
  let urlScheme: String = {
    guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
      return ""
    }

    var result = ""
    if let urlTypeDictionary = urlTypes.first,
      let urlSchemes = urlTypeDictionary["CFBundleURLSchemes"] as? [String],
      let urlScheme = urlSchemes.first {
      result = urlScheme
    }

    return result
  }()

  let appBuildString: String = {
    guard let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String else {
      return ""
    }
    return build
  }()

  let interfaceType: String = {
    #if compiler(>=5.9.2)
    if #available(iOS 17.0, *) {
      if UIDevice.current.userInterfaceIdiom == .vision {
        return "vision"
      }
    }
    #endif
    // Ignore the exhaustive message because we need to be able to let devs using lower versions
    // of xcode to build and they don't have vision support.
    switch UIDevice.current.userInterfaceIdiom {
    case .pad:
      return "ipad"
    case .phone:
      return "iphone"
    case .mac:
      return "mac"
    case .carPlay:
      return "carplay"
    case .tv:
      return "tv"
    case .unspecified:
      fallthrough
    @unknown default:
      return "unspecified"
    }
  }()

  private let appInstallDate: Date? = {
    guard let urlToDocumentsFolder = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).last else {
      return nil
    }

    guard let installDate = try? FileManager.default.attributesOfItem(
      atPath: urlToDocumentsFolder.path
    )[FileAttributeKey.creationDate] as? Date else {
      return nil
    }
    return installDate
  }()

  private let sdkVersionPadded: String
  private let appVersionPadded: String

  private var daysSinceInstall: Int {
    let fromDate = appInstallDate ?? Date()
    let toDate = Date()
    let numberOfDays = Calendar.current.dateComponents([.day], from: fromDate, to: toDate)
    return numberOfDays.day ?? 0
  }

  private let localDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private let utcDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private let utcTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  private let localDateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter
  }()

  private let localTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  private var localDateString: String {
    return localDateFormatter.string(from: Date())
  }

  private var localTimeString: String {
    return localTimeFormatter.string(from: Date())
  }

  private var localDateTimeString: String {
    return localDateTimeFormatter.string(from: Date())
  }

  private var utcDateString: String {
    return utcDateFormatter.string(from: Date())
  }

  private var utcTimeString: String {
    return utcTimeFormatter.string(from: Date())
  }

  private var utcDateTimeString: String {
    return rfc3339DateFormatter.string(from: Date())
  }

  private var minutesSinceInstall: Int {
    let fromDate = appInstallDate ?? Date()
    let toDate = Date()
    let numberOfMinutes = Calendar.current.dateComponents([.minute], from: fromDate, to: toDate)
    return numberOfMinutes.minute ?? 0
  }

  private var daysSinceLastPaywallView: Int? {
    guard let fromDate = storage.get(LastPaywallView.self) else {
      return nil
    }
    let toDate = Date()
    let numberOfDays = Calendar.current.dateComponents([.day], from: fromDate, to: toDate)
    return numberOfDays.day
  }

  private var minutesSinceLastPaywallView: Int? {
    guard let fromDate = storage.get(LastPaywallView.self) else {
      return nil
    }
    let toDate = Date()
    let numberOfMinutes = Calendar.current.dateComponents([.minute], from: fromDate, to: toDate)
    return numberOfMinutes.minute
  }

  private var totalPaywallViews: Int {
    return storage.get(TotalPaywallViews.self) ?? 0
  }

  func reviewRequestsTotal() async -> Int {
    return await storage.coreDataManager.countPlacement(
      SuperwallEventObjc.reviewRequested.description,
      interval: .infinity
    )
  }

  func getDeviceAttributes(
    since placement: PlacementData?,
    computedPropertyRequests: [ComputedPropertyRequest]
  ) async -> [String: Any] {
    var dictionary = await getTemplateDevice()

    let computedProperties = await getComputedDevicePropertiesSincePlacement(
      placement,
      requests: computedPropertyRequests
    )
    dictionary += computedProperties

    return dictionary
  }

  private func getComputedDevicePropertiesSincePlacement(
    _ placement: PlacementData?,
    requests computedPropertyRequests: [ComputedPropertyRequest]
  ) async -> [String: Any] {
    var output: [String: Any] = [:]

    for computedPropertyRequest in computedPropertyRequests {
      if let value = await storage.coreDataManager.getComputedPropertySincePlacement(
        placement,
        request: computedPropertyRequest
      ) {
        output[computedPropertyRequest.type.prefix + computedPropertyRequest.placementName] = value
      }
    }

    return output
  }

  static func makePaddedVersion(using version: String) -> String {
    // Separate out the "beta" part from the main version.
    let components = version.split(separator: "-")
    if components.isEmpty {
      return ""
    }
    let versionNumber = String(components[0])

    var appendix = ""

    // If there is a "beta" part...
    if components.count > 1 {
      // Separate out the number from the name, e.g. beta.1 -> [beta, 1]
      let appendixComponents = components[1].split(separator: ".")
      appendix = "-" + String(appendixComponents[0])

      var appendixVersion = ""

      // Pad beta number and add to appendix
      if appendixComponents.count > 1 {
        appendixVersion = String(format: "%03d", Int(appendixComponents[1]) ?? 0)
        appendix += "." + appendixVersion
      }
    }

    // Separate out the version numbers.
    let versionComponents = versionNumber.split(separator: ".")
    var newVersion = ""
    if !versionComponents.isEmpty {
      let major = String(format: "%03d", Int(versionComponents[0]) ?? 0)
      newVersion += major
    }
    if versionComponents.count > 1 {
      let minor = String(format: "%03d", Int(versionComponents[1]) ?? 0)
      newVersion += ".\(minor)"
    }
    if versionComponents.count > 2 {
      let patch = String(format: "%03d", Int(versionComponents[2]) ?? 0)
      newVersion += ".\(patch)"
    }

    newVersion += appendix

    return newVersion
  }

  private let capabilitiesConfig: [Capability] = [
    PaywallEventReceiverCapability(),
    MultiplePaywallUrlsCapability(),
    ConfigRefreshCapability(),
    WebViewTextInteractionCapability(),
    ConfigCaching()
  ]

  private unowned let network: Network
  private unowned let storage: Storage
  private unowned let entitlementsInfo: EntitlementsInfo
  private unowned let receiptManager: ReceiptManager
  private unowned let factory: IdentityFactory
    & LocaleIdentifierFactory
    & WebEntitlementFactory

  init(
    api: Api,
    storage: Storage,
    network: Network,
    entitlementsInfo: EntitlementsInfo,
    receiptManager: ReceiptManager,
    factory: IdentityFactory & LocaleIdentifierFactory & WebEntitlementFactory,
    isUIKitReadSafe: @escaping () -> Bool = { DeviceHelper.isUIKitReadSafe }
  ) {
    self.storage = storage
    self.network = network
    self.entitlementsInfo = entitlementsInfo
    self.appInstalledAtString = appInstallDate?.isoString ?? ""
    self.receiptManager = receiptManager
    self.factory = factory
      reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, api.base.host)
    self.sdkVersionPadded = Self.makePaddedVersion(using: sdkVersion)
    self.appVersionPadded = Self.makePaddedVersion(using: appVersion)
    self.isUIKitReadSafe = isUIKitReadSafe

    // Both are `nil` when `configure` runs before `UIApplicationMain` — they
    // fill on first post-launch read or on app activation.
    self.screenMetrics = Self.makeScreenMetrics(isUIKitReadSafe: isUIKitReadSafe)
    self.uiTraits = Self.makeUITraits(isUIKitReadSafe: isUIKitReadSafe)
    observeUITraitChanges()
    registerForTraitChanges()
  }

  deinit {
    for observer in traitObservers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func getEnrichment(
    maxRetry: Int? = nil,
    timeout: Seconds? = nil
  ) async throws {
    let identityManager = factory.makeIdentityManager()
    let deviceAttributes = await getTemplateDevice()
    let request = EnrichmentRequest(
      user: JSON(identityManager.userAttributes),
      device: JSON(deviceAttributes)
    )
    enrichment = try await network.getEnrichment(
      request: request,
      maxRetry: maxRetry,
      timeout: timeout
    )

    $enrichment.withSnapshot { enrichment in
      if let enrichment = enrichment {
        storage.save(enrichment, forType: LatestEnrichment.self)
      }
    }

    $enrichment.withSnapshot { enrichment in
      if let attributes = enrichment?.user.dictionaryObject {
        Superwall.shared.setUserAttributes(attributes)
      }
    }
  }

  func getTemplateDevice() async -> [String: Any] {
    let identityInfo = await factory.makeIdentityInfo()
    let aliases = [identityInfo.aliasId]

    // Snapshot once. The four trait-derived fields below each go through
    // `currentUITraits`, so reading them separately would schedule four cache
    // refreshes per call and could interleave with one, tearing the snapshot.
    // Taking the snapshot means `interfaceStyle` below resolves the override
    // inline rather than going through ``interfaceStyle``, so the two resolve it
    // the same way by hand — keep them in step.
    let traits = currentUITraits

    let template = DeviceTemplate(
      publicApiKey: storage.apiKey,
      platform: isMac ? "macOS" : "iOS",
      appUserId: identityInfo.appUserId ?? "",
      aliases: aliases,
      vendorId: vendorId,
      appVersion: appVersion,
      appVersionPadded: appVersionPadded,
      osVersion: osVersion,
      deviceModel: model,
      deviceLocale: localeIdentifier,
      preferredLocale: preferredLocaleIdentifier,
      deviceLanguageCode: languageCode,
      preferredLanguageCode: preferredLanguageCode,
      regionCode: regionCode,
      preferredRegionCode: preferredRegionCode,
      deviceCurrencyCode: currencyCode,
      deviceCurrencySymbol: currencySymbol,
      interfaceType: interfaceType,
      timezoneOffset: Int(TimeZone.current.secondsFromGMT()),
      radioType: radioType,
      interfaceStyle: interfaceStyleOverride?.description ?? traits.interfaceStyle,
      fontSize: traits.fontSize,
      fontScale: traits.fontScale,
      preferredContentSizeCategory: traits.preferredContentSizeCategory,
      isLowPowerModeEnabled: isLowPowerModeEnabled == "true",
      isApplePayAvailable: true,
      bundleId: bundleId,
      appInstallDate: appInstalledAtString,
      isMac: isMac,
      daysSinceInstall: daysSinceInstall,
      minutesSinceInstall: minutesSinceInstall,
      daysSinceLastPaywallView: daysSinceLastPaywallView,
      minutesSinceLastPaywallView: minutesSinceLastPaywallView,
      totalPaywallViews: totalPaywallViews,
      totalReviewRequests: await reviewRequestsTotal(),
      utcDate: utcDateString,
      localDate: localDateString,
      utcTime: utcTimeString,
      localTime: localTimeString,
      utcDateTime: utcDateTimeString,
      localDateTime: localDateTimeString,
      isSandbox: isSandbox,
      activeEntitlements: Set(entitlementsInfo.active.map { $0.id }),
      activeEntitlementObjects: entitlementsInfo.active,
      customerInfo: Superwall.shared.customerInfo,
      activeProducts: await receiptManager.getActiveProductIds(),
      subscriptionStatus: Superwall.shared.subscriptionStatus.description,
      isFirstAppOpen: isFirstAppOpen,
      sdkVersion: sdkVersion,
      sdkVersionPadded: sdkVersionPadded,
      appBuildString: appBuildString,
      appBuildStringNumber: Int(appBuildString),
      interfaceStyleMode: interfaceStyleOverride == nil ? "automatic" : "manual",
      capabilities: capabilitiesConfig.namesCommaSeparated(),
      capabilitiesConfig: capabilitiesConfig.toJson(),
      platformWrapper: platformWrapper,
      platformWrapperVersion: platformWrapperVersion,
      swiftVersion: currentSwiftVersion(),
      compilerVersion: currentCompilerVersion(),
      localResourceIds: Superwall.shared.options.localResources.keys.sorted().joined(separator: ","),
      deviceId: factory.makeDeviceId()
    )

    var deviceDictionary = template.toDictionary()

    let enrichmentDict: [String: Any] = $enrichment.withSnapshot { enrichment in
      enrichment?.device.dictionaryObject ?? [:]
    }
    // Merge in enrichment dictionary, giving priority to
    // the existing values.
    deviceDictionary.merge(enrichmentDict) { current, _ in current }

    if #available(iOS 15.0, *),
      let storefront = await Storefront.current {
      deviceDictionary["storeFrontCountryCode"] = storefront.countryCode
      deviceDictionary["storeFrontId"] = storefront.id

      #if compiler(>=6.1)
      if #available(iOS 17.0, *) {
        deviceDictionary["storeFrontCurrency"] = storefront.currency?.identifier
      }
      #endif
    }

    if Superwall.shared.options.enableExperimentalDeviceVariables {
      let properties = await receiptManager.getExperimentalDeviceProperties()
      deviceDictionary.merge(properties) { current, _ in current }
    }

    deviceDictionary["appTransactionId"] = ReceiptManager.appTransactionId

    return deviceDictionary
  }
}
