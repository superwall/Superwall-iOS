//
//  TestModeManagerTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-02-06.
//
// swiftlint:disable all

@testable import SuperwallKit
import Testing
import Foundation

struct TestModeManagerTests {
  @Test
  func evaluateTestMode_activatesForMatchingUserId() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!

    let appUserId = dependencyContainer.identityManager.appUserId ?? "test_user"
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .userId, value: appUserId)
      ])

    manager.evaluateTestMode(config: config)

    #expect(manager.isTestMode == true)
    #expect(manager.testModeReason != nil)
  }

  @Test
  func evaluateTestMode_activatesForMatchingAliasId() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!

    let aliasId = dependencyContainer.identityManager.aliasId
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .aliasId, value: aliasId)
      ])

    manager.evaluateTestMode(config: config)

    #expect(manager.isTestMode == true)
  }

  @Test
  func evaluateTestMode_doesNotActivateWhenNoMatch() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!

    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .userId, value: "nonexistent_user")
      ])

    manager.evaluateTestMode(config: config)

    #expect(manager.isTestMode == false)
    #expect(manager.testModeReason == nil)
  }

  @Test
  func evaluateTestMode_clearsStateWhenDeactivated() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!
    let storage = dependencyContainer.storage

    let aliasId = dependencyContainer.identityManager.aliasId

    // First, activate test mode
    let activeConfig = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .aliasId, value: aliasId)
      ])
    manager.evaluateTestMode(config: activeConfig)
    #expect(manager.isTestMode == true)

    // Simulate user selecting entitlements and free trial override
    manager.setEntitlements(Set(["premium", "pro"]))
    manager.freeTrialOverride = .forceAvailable

    // Save settings to UserDefaults (as the modal would)
    UserDefaults.standard.set(
      ["premium": true, "pro": true],
      forKey: "com.superwall.testmode.entitlementSettings"
    )
    UserDefaults.standard.set(
      "forceAvailable",
      forKey: "com.superwall.testmode.freeTrialOverride"
    )
    storage.save(true, forType: IsTestModeActiveSubscription.self)

    // Now deactivate test mode (user removed from dashboard)
    let inactiveConfig = Config.stub()
      .setting(\.testModeUserIds, to: [])
    manager.evaluateTestMode(config: inactiveConfig)

    // Verify all state is cleaned up
    #expect(manager.isTestMode == false)
    #expect(manager.testModeReason == nil)
    #expect(manager.testEntitlementIds.isEmpty)
    #expect(manager.freeTrialOverride == .useDefault)
    #expect(manager.products.isEmpty)

    // Verify persisted settings are cleared
    #expect(
      UserDefaults.standard.object(forKey: "com.superwall.testmode.entitlementSettings") == nil
    )
    #expect(
      UserDefaults.standard.object(forKey: "com.superwall.testmode.freeTrialOverride") == nil
    )
    #expect(
      (storage.get(IsTestModeActiveSubscription.self) ?? false) == false
    )
  }

  @Test
  func evaluateTestMode_doesNotClearStateWhenStillActive() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!

    let aliasId = dependencyContainer.identityManager.aliasId

    // Activate test mode
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .aliasId, value: aliasId)
      ])
    manager.evaluateTestMode(config: config)

    // Set some state
    manager.setEntitlements(Set(["premium"]))
    manager.freeTrialOverride = .forceAvailable

    // Re-evaluate with the same config (still active)
    manager.evaluateTestMode(config: config)

    // State should be preserved
    #expect(manager.isTestMode == true)
    #expect(manager.testEntitlementIds == Set(["premium"]))
    #expect(manager.freeTrialOverride == .forceAvailable)
  }
}
