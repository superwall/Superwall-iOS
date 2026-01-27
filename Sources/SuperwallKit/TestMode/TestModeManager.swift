//
//  TestModeManager.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import Foundation

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
    case .bundleIdMismatch(let expected, let actual):
      return "Bundle ID mismatch: expected \(expected), got \(actual)"
    }
  }
}

/// Manages test mode state for the current user.
///
/// Test mode allows Superwall to simulate purchases without involving
/// StoreKit or external purchase controllers. When active, purchases are
/// faked and entitlements are set directly.
class TestModeManager {
  /// Whether the current user is in test mode.
  private(set) var isTestMode: Bool = false

  /// The reason test mode is active, if applicable.
  private(set) var testModeReason: TestModeReason?

  /// Products fetched from the `/v1/products` endpoint for test mode use.
  private(set) var products: [SuperwallProduct] = []

  /// Entitlements set via test mode purchases.
  private(set) var testEntitlementIds: Set<String> = []

  unowned let identityManager: IdentityManager
  private unowned let deviceHelper: DeviceHelper

  init(
    identityManager: IdentityManager,
    deviceHelper: DeviceHelper
  ) {
    self.identityManager = identityManager
    self.deviceHelper = deviceHelper
  }

  /// Evaluates whether the current user should be in test mode based on the config.
  /// Called on every config refresh.
  func evaluateTestMode(config: Config) {
    let testStoreUsers = config.testStoreUsers ?? []

    // Check if current user matches any test store user
    let aliasId = identityManager.aliasId
    let appUserId = identityManager.appUserId

    for testUser in testStoreUsers {
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
      case .vendorId:
        if deviceHelper.vendorId == testUser.value {
          isTestMode = true
          testModeReason = .configMatch
          return
        }
      }
    }

    isTestMode = false
    testModeReason = nil
  }

  /// Sets the products available for test mode purchases.
  func setProducts(_ products: [SuperwallProduct]) {
    self.products = products
  }

  /// Simulates a purchase by adding the product's entitlements.
  func fakePurchase(entitlementIds: [Int]) {
    for id in entitlementIds {
      testEntitlementIds.insert(String(id))
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
}
