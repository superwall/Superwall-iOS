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

  /// The `enableDebugMode` option was explicitly set.
  case debugOption

  /// The app's bundle ID doesn't match the config's `bundleIds.ios`.
  case bundleIdMismatch(expected: String, actual: String)

  var description: String {
    switch self {
    case .configMatch:
      return "User is in test mode (enabled from dashboard)"
    case .debugOption:
      return "Debug mode is enabled via SuperwallOptions"
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

  /// Evaluates whether the current user should be in test mode based on the config.
  /// Called on every config refresh.
  func evaluateTestMode(config: Config) {
    let testModeUserIds = config.testModeUserIds ?? []

    // Check if current user matches any test store user
    let aliasId = identityManager.aliasId
    let appUserId = identityManager.appUserId

    for testUser in testModeUserIds {
      switch testUser.type {
      case .userId:
        if let appUserId, appUserId == testUser.value {
          isTestMode = true
          testModeReason = .configMatch
          return
        }
      case .aliasId:
        if aliasId == testUser.value {
          isTestMode = true
          testModeReason = .configMatch
          return
        }
      }
    }

    // Check bundle ID mismatch (only if bundleIdConfig is present in config)
    if let expectedBundleId = config.bundleIdConfig,
      let actualBundleId = Bundle.main.bundleIdentifier,
      expectedBundleId != actualBundleId {
      isTestMode = true
      testModeReason = .bundleIdMismatch(expected: expectedBundleId, actual: actualBundleId)
      return
    }

    isTestMode = false
    testModeReason = nil
    clearTestModeState()
  }

  /// Clears all test mode state including entitlements, products,
  /// free trial override, and persisted UserDefaults settings.
  private func clearTestModeState() {
    testEntitlementIds.removeAll()
    products.removeAll()
    freeTrialOverride = .useDefault
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
