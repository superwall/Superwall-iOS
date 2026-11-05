//
//  TestModeManager.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import Foundation

/// Override for free trial availability in test mode.
enum FreeTrialOverride: String, CaseIterable, Sendable {
  /// Use the product's actual free trial availability.
  case useDefault
  /// Force free trial to be available.
  case forceAvailable
  /// Force free trial to be unavailable.
  case forceUnavailable

  var displayName: String {
    switch self {
    case .useDefault:
      return "Use Default"
    case .forceAvailable:
      return "Force Available"
    case .forceUnavailable:
      return "Force Unavailable"
    }
  }
}

/// The reason why the user is in test mode.
enum TestModeReason: Sendable {
  /// The user's alias ID matched a test store user from the config.
  case configMatch

  /// Test mode is always enabled via SuperwallOptions.
  case testModeOption

  /// The app's bundle ID doesn't match the config's `bundleIds.ios`, in a
  /// build that isn't from the App Store.
  case bundleIdMismatch(expected: String, actual: String)

  /// Whether the config itself asked for test mode, as opposed to an option
  /// the app set. Only a config can change between launches, so only these
  /// reasons can come from a config saved by an earlier launch.
  var comesFromConfig: Bool {
    switch self {
    case .configMatch,
      .bundleIdMismatch:
      return true
    case .testModeOption:
      return false
    }
  }

  var description: String {
    switch self {
    case .configMatch:
      return "User is in test mode (enabled from dashboard)"
    case .testModeOption:
      return "Test mode is always enabled via SuperwallOptions"
    case let .bundleIdMismatch(expected, actual):
      return "Bundle ID mismatch: expected \(expected), got \(actual)"
    }
  }
}

/// Manages test mode state for the current user.
///
/// Test mode allows Superwall to simulate purchases without involving
/// StoreKit or external purchase controllers. When active, purchases are
/// faked and entitlements are set directly.
///
/// The state lives in a ``TestModeStore``, so it can be read from any thread.
final class TestModeManager {
  let store = TestModeStore(initial: .inactive)

  /// What test mode knows right now.
  var state: TestModeState {
    store.state
  }

  /// Whether the current user is in test mode.
  var isTestMode: Bool {
    state.isActive
  }

  /// The reason test mode is active, if applicable.
  var testModeReason: TestModeReason? {
    state.reason
  }

  /// Products fetched from the `/v1/products` endpoint for test mode use.
  var products: [SuperwallProduct] {
    state.session?.products ?? []
  }

  /// The entitlements the tester has picked or bought.
  var testEntitlementIds: Set<String> {
    state.session?.entitlementIds ?? []
  }

  /// Override for free trial availability.
  var freeTrialOverride: FreeTrialOverride {
    state.session?.freeTrialOverride ?? .useDefault
  }

  /// The subscription status test mode keeps, which replaces other writes to
  /// `subscriptionStatus`. Always `nil` while test mode is off.
  var overriddenSubscriptionStatus: SubscriptionStatus? {
    state.session?.overriddenSubscriptionStatus
  }

  /// The customer info test mode keeps, which replaces other writes to
  /// `customerInfo`. Always `nil` while test mode is off.
  var overriddenCustomerInfo: CustomerInfo? {
    state.session?.overriddenCustomerInfo
  }

  /// Whether the process is running inside a test environment.
  /// Returns `false` when `SUPERWALL_UNIT_TESTS` launch argument is present
  /// (used by internal unit tests to avoid skipping test mode).
  static let isTestEnvironment: Bool = {
    if ProcessInfo.processInfo.arguments.contains("SUPERWALL_UNIT_TESTS") {
      return false
    }
    return NSClassFromString("XCTestCase") != nil
  }()

  /// Whether the app is running outside App Store production: simulator,
  /// TestFlight or a development build. Replaced in tests.
  var isSandboxEnvironment: () -> Bool = { DeviceHelper.isSandboxEnvironment }

  unowned let identityManager: IdentityManager
  private unowned let deviceHelper: DeviceHelper
  private unowned let storage: Storage

  init(
    identityManager: IdentityManager,
    deviceHelper: DeviceHelper,
    storage: Storage
  ) {
    self.identityManager = identityManager
    self.deviceHelper = deviceHelper
    self.storage = storage
  }

  /// Evaluates whether the current user should be in test mode based on the config
  /// and the `testModeBehavior` option. Called on every config refresh.
  ///
  /// - Returns: The reason test mode is now on, or `nil` if it's off.
  @discardableResult
  func evaluateTestMode(config: Config, options: SuperwallOptions) -> TestModeReason? {
    guard let reason = reasonForTestMode(
      config: config,
      options: options,
      warnAboutIgnoredMismatch: true
    ) else {
      store.update(TestModeUpdate.deactivate)
      clearSavedSettings()
      return nil
    }
    store.update(TestModeUpdate.activate(reason))
    return reason
  }

  /// Why `config` and `options` would put the current user in test mode, or
  /// `nil` if they wouldn't. Changes nothing, so a config can be checked before
  /// it is used.
  func reasonForTestMode(config: Config, options: SuperwallOptions) -> TestModeReason? {
    return reasonForTestMode(config: config, options: options, warnAboutIgnoredMismatch: false)
  }

  private func reasonForTestMode(
    config: Config,
    options: SuperwallOptions,
    warnAboutIgnoredMismatch: Bool
  ) -> TestModeReason? {
    #if !canImport(WebKit)
    // Test mode picks entitlements and simulates purchases in its own screens,
    // which watchOS and tvOS don't have.
    return nil
    #else
    if DevMode.isActive(options) {
      return .testModeOption
    }
    switch options.testModeBehavior {
    case .never:
      return nil
    case .always:
      return .testModeOption
    case .whenEnabledForUser:
      // Only check user ID match, skip bundle ID check
      return configMatchReason(config: config)
    case .automatic:
      // Skip entirely if in UI tests
      if Self.isTestEnvironment {
        return nil
      }
      // Check user match, then bundle ID mismatch
      return configMatchReason(config: config)
        ?? bundleIdMismatchReason(config: config, warnIfIgnored: warnAboutIgnoredMismatch)
    }
    #endif
  }

  /// Whether `config` itself would put the current user in test mode. Such a
  /// config must never be the one a launch starts from: see
  /// `ConfigManager.cachedConfigForLaunch()`.
  func isPutInTestMode(by config: Config, options: SuperwallOptions) -> Bool {
    return reasonForTestMode(config: config, options: options)?.comesFromConfig == true
  }

  /// The reason if the current user's ID or alias matches any test store user in the config.
  private func configMatchReason(config: Config) -> TestModeReason? {
    let testModeUserIds = config.testModeUserIds ?? []
    let aliasId = identityManager.aliasId
    let appUserId = identityManager.appUserId

    for testUser in testModeUserIds {
      switch testUser.type {
      case .userId:
        if let appUserId, appUserId == testUser.value {
          return .configMatch
        }
      case .aliasId:
        if aliasId == testUser.value {
          return .configMatch
        }
      }
    }
    return nil
  }

  /// The reason if the app's bundle ID differs from the config's expected bundle ID.
  /// App extensions are allowed because their bundle ID uses the main app's
  /// bundle ID as a prefix (e.g., `com.example.app.widget-extension`).
  ///
  /// - Parameter warnIfIgnored: Whether to log when an App Store build ignores
  ///   the mismatch. Only set when the config is being applied, so the warning
  ///   shows once per config rather than on every check.
  private func bundleIdMismatchReason(config: Config, warnIfIgnored: Bool) -> TestModeReason? {
    guard
      let expectedBundleId = config.bundleIdConfig,
      let actualBundleId = Bundle.main.bundleIdentifier,
      expectedBundleId != actualBundleId,
      !actualBundleId.hasPrefix(expectedBundleId + ".")
    else {
      return nil
    }
    // A mismatch is how a developer's own build gets into test mode without
    // any setup. An App Store install is a customer's, and the mismatch there
    // means the bundle ID on the dashboard was edited, which must not replace
    // their real purchases with simulated ones. Test users marked on the
    // dashboard still get test mode in an App Store build.
    guard isSandboxEnvironment() else {
      if !warnIfIgnored {
        return nil
      }
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "The app's bundle ID is \(actualBundleId) but the Superwall dashboard expects "
          + "\(expectedBundleId). Ignoring the mismatch because this is an App Store build, "
          + "so test mode stays off. Correct the bundle ID in the dashboard's app settings."
      )
      return nil
    }
    return .bundleIdMismatch(expected: expectedBundleId, actual: actualBundleId)
  }

  /// Forgets the tester's saved choices, so the next time test mode turns
  /// on starts from the defaults.
  private func clearSavedSettings() {
    #if canImport(WebKit)
    TestModeSettingsStore.clear()
    #endif
    storage.save(false, forType: IsTestModeActiveSubscription.self)
  }

  /// Sets the products available for test mode purchases.
  func setProducts(_ products: [SuperwallProduct]) {
    store.update(TestModeUpdate.products(products))
  }

  func setFreeTrialOverride(_ override: FreeTrialOverride) {
    store.update(TestModeUpdate.freeTrialOverride(override))
  }

  /// Adds the entitlements of a simulated purchase.
  ///
  /// - Returns: The session afterwards, or `nil` if test mode is off.
  @discardableResult
  func recordPurchase(of entitlements: [SuperwallEntitlementRef]) -> TestModeSession? {
    store.update(TestModeUpdate.purchased(entitlementIds: Set(entitlements.map { $0.identifier })))
    return state.session
  }

  /// Replaces the entitlements with those the tester picked.
  ///
  /// - Returns: The session afterwards, or `nil` if test mode is off.
  @discardableResult
  func choose(_ entitlements: Set<Entitlement>) -> TestModeSession? {
    store.update(TestModeUpdate.chose(entitlements: entitlements))
    return state.session
  }

  /// Sends the customer info and subscription status that `session` keeps to
  /// the SDK.
  @MainActor
  func sendOverrides(of session: TestModeSession?) {
    if let customerInfo = session?.overriddenCustomerInfo {
      Superwall.shared.customerInfo = customerInfo
    }
    if let status = session?.overriddenSubscriptionStatus {
      Superwall.shared.setSubscriptionStatus(assigned: status)
    }
  }

  /// Returns whether free trial should be shown for a product, applying the override.
  func shouldShowFreeTrial(for product: StoreProduct) -> Bool {
    switch freeTrialOverride {
    case .useDefault:
      return product.hasFreeTrial
    case .forceAvailable:
      return true
    case .forceUnavailable:
      return false
    }
  }
}
