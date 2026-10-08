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

  /// The app's bundle ID doesn't match the config's `bundleIds.ios`.
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
final class TestModeManager {
  /// Whether the current user is in test mode.
  private(set) var isTestMode: Bool = false

  /// The reason test mode is active, if applicable.
  private(set) var testModeReason: TestModeReason?

  /// Products fetched from the `/v1/products` endpoint for test mode use.
  private(set) var products: [SuperwallProduct] = []

  /// Entitlements set via test mode purchases.
  private(set) var testEntitlementIds: Set<String> = []

  /// Override for free trial availability.
  var freeTrialOverride: FreeTrialOverride = .useDefault

  /// The subscription status that test mode wants to maintain.
  /// When set, external writes to `subscriptionStatus` are
  /// overridden with this value.
  var overriddenSubscriptionStatus: SubscriptionStatus?

  /// The customer info that test mode wants to maintain.
  /// When set, external writes to `customerInfo` are
  /// overridden with this value.
  var overriddenCustomerInfo: CustomerInfo?

  /// Whether the process is running inside a test environment.
  /// Returns `false` when `SUPERWALL_UNIT_TESTS` launch argument is present
  /// (used by internal unit tests to avoid skipping test mode).
  static let isTestEnvironment: Bool = {
    if ProcessInfo.processInfo.arguments.contains("SUPERWALL_UNIT_TESTS") {
      return false
    }
    return NSClassFromString("XCTestCase") != nil
  }()

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
  func evaluateTestMode(config: Config, options: SuperwallOptions) {
    guard let reason = reasonForTestMode(config: config, options: options) else {
      isTestMode = false
      testModeReason = nil
      clearTestModeState()
      return
    }
    isTestMode = true
    testModeReason = reason
  }

  /// Why `config` and `options` would put the current user in test mode, or
  /// `nil` if they wouldn't. Changes nothing, so a config can be checked before
  /// it is used.
  func reasonForTestMode(config: Config, options: SuperwallOptions) -> TestModeReason? {
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
      return configMatchReason(config: config) ?? bundleIdMismatchReason(config: config)
    }
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
  private func bundleIdMismatchReason(config: Config) -> TestModeReason? {
    guard
      let expectedBundleId = config.bundleIdConfig,
      let actualBundleId = Bundle.main.bundleIdentifier,
      expectedBundleId != actualBundleId,
      !actualBundleId.hasPrefix(expectedBundleId + ".")
    else {
      return nil
    }
    return .bundleIdMismatch(expected: expectedBundleId, actual: actualBundleId)
  }

  /// Clears all test mode state including entitlements, products,
  /// free trial override, and persisted UserDefaults settings.
  private func clearTestModeState() {
    testEntitlementIds.removeAll()
    products.removeAll()
    freeTrialOverride = .useDefault
    overriddenSubscriptionStatus = nil
    overriddenCustomerInfo = nil
    UserDefaults.standard.removeObject(forKey: "com.superwall.testmode.entitlementSettings")
    UserDefaults.standard.removeObject(forKey: "com.superwall.testmode.freeTrialOverride")
    storage.save(false, forType: IsTestModeActiveSubscription.self)
  }

  /// Sets the products available for test mode purchases.
  func setProducts(_ products: [SuperwallProduct]) {
    self.products = products
  }

  /// Simulates a purchase by adding the product's entitlements.
  func fakePurchase(entitlements: [SuperwallEntitlementRef]) {
    for entitlement in entitlements {
      testEntitlementIds.insert(entitlement.identifier)
    }
  }

  /// Resets test entitlements (used when restoring in test mode).
  func resetEntitlements() {
    testEntitlementIds.removeAll()
  }

  /// Sets entitlements from an entitlement picker selection.
  func setEntitlements(_ entitlementIds: Set<String>) {
    testEntitlementIds = entitlementIds
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
