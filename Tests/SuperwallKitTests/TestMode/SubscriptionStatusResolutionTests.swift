//
//  SubscriptionStatusResolutionTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-02-06.
//
// swiftlint:disable all

@testable import SuperwallKit
import Testing
import Foundation

struct SubscriptionStatusResolutionTests {
  // MARK: - subscriptionStatus resolution

  @Test
  func subscriptionStatus_testModeOverride_appliesOverride() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeManager = dependencyContainer.testModeManager!

    // Activate test mode
    let aliasId = dependencyContainer.identityManager.aliasId
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .aliasId, value: aliasId)
      ])
    testModeManager.evaluateTestMode(config: config, options: SuperwallOptions())

    // Set a test mode override
    let overrideEntitlement = Entitlement(id: "test_premium")
    let overrideStatus: SubscriptionStatus = .active(Set([overrideEntitlement]))
    testModeManager.overriddenSubscriptionStatus = overrideStatus

    // Attempt to set a different status externally
    superwall.subscriptionStatus = .inactive

    // Should resolve to the test mode override
    #expect(superwall.subscriptionStatus == overrideStatus)
  }

  @Test
  func subscriptionStatus_testModeOverride_allowsSameValue() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeManager = dependencyContainer.testModeManager!

    // Activate test mode
    let aliasId = dependencyContainer.identityManager.aliasId
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .aliasId, value: aliasId)
      ])
    testModeManager.evaluateTestMode(config: config, options: SuperwallOptions())

    // Set override to inactive
    testModeManager.overriddenSubscriptionStatus = .inactive

    // Set the same value — should not trigger re-assignment
    superwall.subscriptionStatus = .inactive

    #expect(superwall.subscriptionStatus == .inactive)
  }

  @Test
  func subscriptionStatus_noTestMode_passesThrough() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // No test mode active
    let entitlement = Entitlement(id: "premium")
    let status: SubscriptionStatus = .active(Set([entitlement]))
    superwall.subscriptionStatus = status

    #expect(superwall.subscriptionStatus == status)
  }

  @Test
  func subscriptionStatus_activeWithEmptyEntitlements_resolvesToInactive() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // Set active with empty entitlements
    superwall.subscriptionStatus = .active(Set())

    // Should resolve to inactive
    #expect(superwall.subscriptionStatus == .inactive)
  }

  @Test
  func subscriptionStatus_testModeNotActive_noOverrideApplied() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeManager = dependencyContainer.testModeManager!

    // Test mode exists but is NOT active
    #expect(testModeManager.isTestMode == false)

    // Even if someone incorrectly sets an override, it shouldn't apply
    testModeManager.overriddenSubscriptionStatus = .active(Set([Entitlement(id: "hack")]))

    superwall.subscriptionStatus = .inactive

    #expect(superwall.subscriptionStatus == .inactive)
  }

  @Test
  func subscriptionStatus_testModeOverrideIsNil_passesThrough() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeManager = dependencyContainer.testModeManager!

    // Activate test mode but don't set an override
    let aliasId = dependencyContainer.identityManager.aliasId
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .aliasId, value: aliasId)
      ])
    testModeManager.evaluateTestMode(config: config, options: SuperwallOptions())
    #expect(testModeManager.isTestMode == true)
    #expect(testModeManager.overriddenSubscriptionStatus == nil)

    // Set a value — should pass through since override is nil
    let entitlement = Entitlement(id: "premium")
    superwall.subscriptionStatus = .active(Set([entitlement]))

    #expect(superwall.subscriptionStatus == .active(Set([entitlement])))
  }

  // MARK: - customerInfo resolution

  @Test
  func customerInfo_testModeOverride_appliesOverride() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeManager = dependencyContainer.testModeManager!

    // Activate test mode
    let aliasId = dependencyContainer.identityManager.aliasId
    let config = Config.stub()
      .setting(\.testModeUserIds, to: [
        TestStoreUser(type: .aliasId, value: aliasId)
      ])
    testModeManager.evaluateTestMode(config: config, options: SuperwallOptions())

    // Set a test mode override
    let overrideInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [Entitlement(id: "test_entitlement")]
    )
    testModeManager.overriddenCustomerInfo = overrideInfo

    // Attempt to set different customer info
    let externalInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: []
    )
    superwall.customerInfo = externalInfo

    // Should resolve to the test mode override
    #expect(superwall.customerInfo == overrideInfo)
  }

  @Test
  func customerInfo_noTestMode_passesThrough() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    let info = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [Entitlement(id: "premium")]
    )
    superwall.customerInfo = info

    #expect(superwall.customerInfo == info)
  }

  @Test
  func customerInfo_testModeNotActive_noOverrideApplied() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeManager = dependencyContainer.testModeManager!

    #expect(testModeManager.isTestMode == false)

    let overrideInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [Entitlement(id: "should_not_apply")]
    )
    testModeManager.overriddenCustomerInfo = overrideInfo

    let externalInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: []
    )
    superwall.customerInfo = externalInfo

    #expect(superwall.customerInfo == externalInfo)
  }
}
