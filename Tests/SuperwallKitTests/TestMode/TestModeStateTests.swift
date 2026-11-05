//
//  TestModeStateTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

@Suite("TestModeUpdate reducers")
struct TestModeUpdateTests {
  private func activeState(_ change: (inout TestModeSession) -> Void = { _ in }) -> TestModeState {
    var session = TestModeSession()
    change(&session)
    return .active(reason: .testModeOption, session: session)
  }

  @Test("activate turns test mode on with an empty session")
  func activateFromInactive() {
    let state = TestModeUpdate.activate(.configMatch).reduce(.inactive)
    #expect(state.isActive)
    if case .configMatch = state.reason {} else {
      Issue.record("Expected .configMatch, got \(String(describing: state.reason))")
    }
    #expect(state.session?.entitlementIds.isEmpty == true)
    #expect(state.session?.freeTrialOverride == .useDefault)
    #expect(state.session?.overriddenSubscriptionStatus == nil)
  }

  @Test("activate while on changes the reason and keeps the session")
  func activateWhileActive() {
    let start = activeState {
      $0.entitlementIds = ["pro"]
      $0.freeTrialOverride = .forceAvailable
    }
    let state = TestModeUpdate.activate(.configMatch).reduce(start)
    if case .configMatch = state.reason {} else {
      Issue.record("Expected .configMatch, got \(String(describing: state.reason))")
    }
    #expect(state.session?.entitlementIds == ["pro"])
    #expect(state.session?.freeTrialOverride == .forceAvailable)
  }

  @Test("deactivate forgets the session")
  func deactivate() {
    let start = activeState {
      $0.entitlementIds = ["pro"]
      $0.overriddenSubscriptionStatus = .inactive
    }
    let state = TestModeUpdate.deactivate.reduce(start)
    #expect(!state.isActive)
    #expect(state.reason == nil)
    #expect(state.session == nil)
  }

  @Test("Updates other than activate leave an inactive state alone")
  func inactiveIgnoresUpdates() {
    let updates: [TestModeUpdate] = [
      .products([]),
      .freeTrialOverride(.forceAvailable),
      .purchased(entitlementIds: ["pro"]),
      .chose(entitlements: [Entitlement(id: "pro")]),
    ]
    for update in updates {
      let state = update.reduce(.inactive)
      #expect(!state.isActive)
      #expect(state.session == nil)
    }
  }

  @Test("freeTrialOverride changes only the override")
  func freeTrialOverride() {
    let start = activeState { $0.entitlementIds = ["pro"] }
    let state = TestModeUpdate.freeTrialOverride(.forceUnavailable).reduce(start)
    #expect(state.session?.freeTrialOverride == .forceUnavailable)
    #expect(state.session?.entitlementIds == ["pro"])
  }

  @Test("purchased adds to the entitlements held, all subscribed")
  func purchased() {
    let start = activeState { $0.entitlementIds = ["basic"] }
    let state = TestModeUpdate.purchased(entitlementIds: ["pro"]).reduce(start)
    let session = state.session
    #expect(session?.entitlementIds == ["basic", "pro"])

    let entitlements = session?.overriddenCustomerInfo?.entitlements ?? []
    #expect(Set(entitlements.map(\.id)) == ["basic", "pro"])
    #expect(entitlements.allSatisfy { $0.isActive && $0.state == .subscribed })

    guard case .active(let active) = session?.overriddenSubscriptionStatus else {
      Issue.record("Expected an active status")
      return
    }
    #expect(Set(active.map(\.id)) == ["basic", "pro"])
  }

  @Test("chose replaces the entitlements held")
  func chose() {
    let start = activeState { $0.entitlementIds = ["basic"] }
    let pro = Entitlement(id: "pro")
    let state = TestModeUpdate.chose(entitlements: [pro]).reduce(start)
    #expect(state.session?.entitlementIds == ["pro"])
    #expect(state.session?.overriddenCustomerInfo?.entitlements == [pro])
    #expect(state.session?.overriddenSubscriptionStatus == .active([pro]))
  }

  @Test("chose with only inactive entitlements keeps them but the status is inactive")
  func choseInactive() {
    let expired = Entitlement(id: "pro", type: .serviceLevel, isActive: false, store: .appStore, state: .expired)
    let state = TestModeUpdate.chose(entitlements: [expired]).reduce(activeState())
    #expect(state.session?.entitlementIds == ["pro"])
    #expect(state.session?.overriddenCustomerInfo?.entitlements == [expired])
    #expect(state.session?.overriddenSubscriptionStatus == .inactive)
  }

  @Test("chose with nothing clears the entitlements")
  func choseNothing() {
    let start = activeState { $0.entitlementIds = ["pro"] }
    let state = TestModeUpdate.chose(entitlements: []).reduce(start)
    #expect(state.session?.entitlementIds.isEmpty == true)
    #expect(state.session?.overriddenCustomerInfo?.entitlements.isEmpty == true)
    #expect(state.session?.overriddenSubscriptionStatus == .inactive)
  }
}

@Suite("TestModeManager store")
struct TestModeManagerStoreTests {
  /// The container owns what the manager holds unowned references to, so
  /// tests keep it alive until they finish.
  private func makeActiveManager() -> (TestModeManager, DependencyContainer) {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.testModeManager!
    let options = SuperwallOptions()
    options.testModeBehavior = .always
    manager.evaluateTestMode(config: .stub(), options: options)
    return (manager, dependencyContainer)
  }

  @Test("Purchases made at the same time on many threads are all kept")
  func concurrentPurchasesAreAllKept() async {
    let (manager, container) = makeActiveManager()
    let ids = (0..<200).map { "entitlement_\($0)" }

    await withTaskGroup(of: Void.self) { group in
      for id in ids {
        group.addTask {
          manager.recordPurchase(of: [SuperwallEntitlementRef(identifier: id, type: "SERVICE_LEVEL")])
        }
      }
    }

    #expect(manager.testEntitlementIds == Set(ids))
    let status = manager.overriddenSubscriptionStatus
    guard case .active(let entitlements) = status else {
      Issue.record("Expected an active status, got \(String(describing: status))")
      return
    }
    #expect(entitlements.count == 200)
    withExtendedLifetime(container) {}
  }

  @Test("Observers hear 200 concurrent updates in the order they were applied")
  func observersHearUpdatesInOrder() async {
    let (manager, container) = makeActiveManager()
    let counts = LockedArray()
    manager.store.observe { before, after in
      counts.append((before.session?.entitlementIds.count ?? -1, after.session?.entitlementIds.count ?? -1))
    }

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 {
        group.addTask {
          manager.recordPurchase(of: [SuperwallEntitlementRef(identifier: "e\(index)", type: "SERVICE_LEVEL")])
        }
      }
    }

    let heard = counts.values
    #expect(heard.count == 200)
    for (offset, pair) in heard.enumerated() {
      #expect(pair.0 == offset)
      #expect(pair.1 == offset + 1)
    }
    withExtendedLifetime(container) {}
  }

  @Test("Turning test mode off forgets the session and the saved settings")
  func deactivationForgetsEverything() {
    let (manager, container) = makeActiveManager()
    manager.setFreeTrialOverride(.forceAvailable)
    manager.recordPurchase(of: [SuperwallEntitlementRef(identifier: "pro", type: "SERVICE_LEVEL")])
    TestModeSettingsStore.save(
      ["pro": EntitlementSelection(state: .subscribed, offerType: nil)],
      freeTrialOverride: .forceAvailable
    )

    manager.evaluateTestMode(config: .stub(), options: SuperwallOptions())

    #expect(manager.state.session == nil)
    #expect(manager.products.isEmpty)
    #expect(manager.testEntitlementIds.isEmpty)
    #expect(manager.freeTrialOverride == .useDefault)
    #expect(manager.overriddenSubscriptionStatus == nil)
    #expect(manager.overriddenCustomerInfo == nil)
    #expect(TestModeSettingsStore.loadSelections().isEmpty)
    withExtendedLifetime(container) {}
  }
}

private final class LockedArray: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [(Int, Int)] = []

  func append(_ value: (Int, Int)) {
    lock.lock()
    storage.append(value)
    lock.unlock()
  }

  var values: [(Int, Int)] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }
}
