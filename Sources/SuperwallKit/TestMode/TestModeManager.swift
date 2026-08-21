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
    switch options.testModeBehavior {
    case .never:
      isTestMode = false
      testModeReason = nil
      clearTestModeState()
      return

    case .always:
      isTestMode = true
      testModeReason = .testModeOption
      return

    case .whenEnabledForUser:
      // Only check user ID match, skip bundle ID check
      if checkConfigMatch(config: config) { return }
      isTestMode = false
      testModeReason = nil
      clearTestModeState()
      return

    case .automatic:
      // Skip entirely if in UI tests
      if Self.isTestEnvironment {
        isTestMode = false
        testModeReason = nil
        clearTestModeState()
        return
      }
      // Check user match, then bundle ID mismatch
      if checkConfigMatch(config: config) { return }
      if checkBundleIdMismatch(config: config) { return }
      isTestMode = false
      testModeReason = nil
      clearTestModeState()
      return
    }
  }

  /// Checks if the current user's ID or alias matches any test store user in the config.
  /// Returns `true` and activates test mode if a match is found.
  private func checkConfigMatch(config: Config) -> Bool {
    let testModeUserIds = config.testModeUserIds ?? []
    let aliasId = identityManager.aliasId
    let appUserId = identityManager.appUserId

    for testUser in testModeUserIds {
      switch testUser.type {
      case .userId:
        if let appUserId, appUserId == testUser.value {
          isTestMode = true
          testModeReason = .configMatch
          return true
        }
      case .aliasId:
        if aliasId == testUser.value {
          isTestMode = true
          testModeReason = .configMatch
          return true
        }
      }
    }
    return false
  }

  /// Checks if the app's bundle ID differs from the config's expected bundle ID.
  /// Returns `true` and activates test mode if a mismatch is found.
  /// App extensions are allowed because their bundle ID uses the main app's
  /// bundle ID as a prefix (e.g., `com.example.app.widget-extension`).
  private func checkBundleIdMismatch(config: Config) -> Bool {
    if let expectedBundleId = config.bundleIdConfig,
      let actualBundleId = Bundle.main.bundleIdentifier,
      expectedBundleId != actualBundleId,
      !actualBundleId.hasPrefix(expectedBundleId + ".") {
      isTestMode = true
      testModeReason = .bundleIdMismatch(expected: expectedBundleId, actual: actualBundleId)
      return true
    }
    return false
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
