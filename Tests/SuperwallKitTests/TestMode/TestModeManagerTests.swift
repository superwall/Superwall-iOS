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
    let identityManager = dependencyContainer.identityManager!
    let manager = dependencyContainer.testModeManager!

    // Identify with a known userId so we can match against it
    identityManager.identify(
      userId: "test_user",
      options: nil
    )

    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .userId, value: "test_user")
      ])

    manager.evaluateTestMode(config: config, options: SuperwallOptions())

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

    manager.evaluateTestMode(config: config, options: SuperwallOptions())

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

    manager.evaluateTestMode(config: config, options: SuperwallOptions())

    #expect(manager.isTestMode == false)
    #expect(manager.testModeReason == nil)
  }

  @Test
  func evaluateTestMode_clearsStateWhenDeactivated() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!
    let storage = dependencyContainer.storage!

    let aliasId = dependencyContainer.identityManager.aliasId

    // First, activate test mode
    let activeConfig = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .aliasId, value: aliasId)
      ])
    manager.evaluateTestMode(config: activeConfig, options: SuperwallOptions())
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
    manager.evaluateTestMode(config: inactiveConfig, options: SuperwallOptions())

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
    manager.evaluateTestMode(config: config, options: SuperwallOptions())

    // Set some state
    manager.setEntitlements(Set(["premium"]))
    manager.freeTrialOverride = .forceAvailable

    // Re-evaluate with the same config (still active)
    manager.evaluateTestMode(config: config, options: SuperwallOptions())

    // State should be preserved
    #expect(manager.isTestMode == true)
    #expect(manager.testEntitlementIds == Set(["premium"]))
    #expect(manager.freeTrialOverride == .forceAvailable)
  }

  // MARK: - TestModeBehavior Tests

  @Test
  func testModeBehavior_never_disablesTestMode() {
    let dependencyContainer = DependencyContainer()
    let identityManager = dependencyContainer.identityManager!
    let manager = dependencyContainer.testModeManager!

    identityManager.identify(userId: "test_user", options: nil)

    // Config that would normally match
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .userId, value: "test_user")
      ])

    let options = SuperwallOptions()
    options.testModeBehavior = .never

    manager.evaluateTestMode(config: config, options: options)

    #expect(manager.isTestMode == false)
    #expect(manager.testModeReason == nil)
  }

  @Test
  func testModeBehavior_always_enablesTestMode() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!

    // Config with no matching users
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [])

    let options = SuperwallOptions()
    options.testModeBehavior = .always

    manager.evaluateTestMode(config: config, options: options)

    #expect(manager.isTestMode == true)
    if case .testModeOption = manager.testModeReason {
      // Expected
    } else {
      #expect(Bool(false), "Expected .testModeOption reason, got \(String(describing: manager.testModeReason))")
    }
  }

  @Test
  func testModeBehavior_whenEnabledForUser_activatesOnConfigMatch() {
    let dependencyContainer = DependencyContainer()
    let identityManager = dependencyContainer.identityManager!
    let manager = dependencyContainer.testModeManager!

    identityManager.identify(userId: "test_user", options: nil)

    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .userId, value: "test_user")
      ])

    let options = SuperwallOptions()
    options.testModeBehavior = .whenEnabledForUser

    manager.evaluateTestMode(config: config, options: options)

    #expect(manager.isTestMode == true)
    if case .configMatch = manager.testModeReason {
      // Expected
    } else {
      #expect(Bool(false), "Expected .configMatch reason, got \(String(describing: manager.testModeReason))")
    }
  }

  @Test
  func testModeBehavior_whenEnabledForUser_doesNotActivateOnBundleIdMismatch() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!

    // Config with a bundle ID that won't match (but no user match)
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [])
      .setting(\.bundleIdConfig, to: "com.some.other.bundle")

    let options = SuperwallOptions()
    options.testModeBehavior = .whenEnabledForUser

    manager.evaluateTestMode(config: config, options: options)

    #expect(manager.isTestMode == false)
    #expect(manager.testModeReason == nil)
  }

  @Test
  func testModeBehavior_automatic_activatesOnConfigMatch() {
    let dependencyContainer = DependencyContainer()
    let identityManager = dependencyContainer.identityManager!
    let manager = dependencyContainer.testModeManager!

    identityManager.identify(userId: "test_user", options: nil)

    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .userId, value: "test_user")
      ])

    let options = SuperwallOptions()
    options.testModeBehavior = .automatic

    manager.evaluateTestMode(config: config, options: options)

    #expect(manager.isTestMode == true)
    if case .configMatch = manager.testModeReason {
      // Expected
    } else {
      #expect(Bool(false), "Expected .configMatch reason, got \(String(describing: manager.testModeReason))")
    }
  }

  @Test
  func testModeBehavior_automatic_doesNotActivateWhenBundleIdIsPrefix() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!

    // Simulate an app extension whose bundle ID has the config bundle ID as a prefix
    let actualBundleId = Bundle.main.bundleIdentifier ?? ""
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [])
      .setting(\.bundleIdConfig, to: actualBundleId)

    let options = SuperwallOptions()
    options.testModeBehavior = .automatic

    // When the config bundle ID exactly matches, test mode should NOT activate
    manager.evaluateTestMode(config: config, options: options)
    #expect(manager.isTestMode == false)

    // Now set the config bundle ID to a prefix of the actual bundle ID
    // (simulating the extension case where actual = "com.app.widget" and config = "com.app")
    if actualBundleId.contains(".") {
      let prefix = String(actualBundleId[..<actualBundleId.lastIndex(of: ".")!])
      let prefixConfig = Config.stub()
        .setting(\.testModeUserIds, to: [])
        .setting(\.bundleIdConfig, to: prefix)

      manager.evaluateTestMode(config: prefixConfig, options: options)
      #expect(manager.isTestMode == false)
      #expect(manager.testModeReason == nil)
    }
  }

  @Test
  func testModeBehavior_automatic_activatesOnBundleIdMismatch() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!

    // Config with a bundle ID that won't match and no user match
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [])
      .setting(\.bundleIdConfig, to: "com.some.other.bundle")

    let options = SuperwallOptions()
    options.testModeBehavior = .automatic

    manager.evaluateTestMode(config: config, options: options)

    #expect(manager.isTestMode == true)
    if case .bundleIdMismatch = manager.testModeReason {
      // Expected
    } else {
      #expect(Bool(false), "Expected .bundleIdMismatch reason, got \(String(describing: manager.testModeReason))")
    }
  }
}
