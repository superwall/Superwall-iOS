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

private func activeState(_ change: (inout TestModeSession) -> Void = { _ in }) -> TestModeState {
  var session = TestModeSession()
  change(&session)
  return TestModeState(mode: .active(reason: .testModeOption, session: session))
}

private let expiredPro = Entitlement(
  id: "pro",
  type: .serviceLevel,
  isActive: false,
  store: .appStore,
  state: .expired
)

@Suite("TestModeUpdate reducers")
struct TestModeUpdateTests {
  @Test("activated turns test mode on with an untouched session")
  func activatedFromInactive() {
    let state = TestModeUpdate.activated(.configMatch).reduce(TestModeState())
    #expect(state.isActive)
    if case .configMatch = state.reason {} else {
      Issue.record("Expected .configMatch, got \(String(describing: state.reason))")
    }
    #expect(state.session?.entitlementIds.isEmpty == true)
    #expect(state.session?.freeTrialOverride == .useDefault)
    #expect(state.session?.overriddenSubscriptionStatus == nil)
    #expect(state.session?.overriddenCustomerInfo == nil)
  }

  @Test("activated while on changes the reason and keeps the session, overrides included")
  func activatedWhileActive() {
    let start = activeState {
      $0.entitlements = .kept([Entitlement(id: "pro")])
      $0.freeTrialOverride = .forceAvailable
    }
    let state = TestModeUpdate.activated(.configMatch).reduce(start)
    if case .configMatch = state.reason {} else {
      Issue.record("Expected .configMatch, got \(String(describing: state.reason))")
    }
    #expect(state.session?.entitlementIds == ["pro"])
    #expect(state.session?.freeTrialOverride == .forceAvailable)
    #expect(state.session?.overriddenSubscriptionStatus == .active([Entitlement(id: "pro")]))
  }

  @Test("deactivated forgets the session")
  func deactivated() {
    let start = activeState { $0.entitlements = .kept([Entitlement(id: "pro")]) }
    let state = TestModeUpdate.deactivated.reduce(start)
    #expect(!state.isActive)
    #expect(state.reason == nil)
    #expect(state.session == nil)
  }

  @Test("Updates other than activated leave an inactive state alone")
  func inactiveIgnoresUpdates() {
    let updates: [TestModeUpdate] = [
      .productsLoaded([]),
      .purchased(entitlementIds: ["pro"]),
      .settingsChosen(entitlements: [Entitlement(id: "pro")], freeTrialOverride: .forceAvailable),
      .restored([Entitlement(id: "pro")]),
      .defaultsApplied,
    ]
    for update in updates {
      let state = update.reduce(TestModeState())
      #expect(!state.isActive)
      #expect(state.session == nil)
    }
  }

  @Test("productsLoaded changes only the products")
  func productsLoaded() throws {
    let product = try JSONDecoder().decode(
      SuperwallProduct.self,
      from: Data(#"{"object":"product","identifier":"pro_monthly","platform":"ios","entitlements":[{"identifier":"pro","type":"SERVICE_LEVEL"}],"storefront":"USA"}"#.utf8)
    )
    let start = activeState {
      $0.entitlements = .kept([Entitlement(id: "pro")])
      $0.freeTrialOverride = .forceAvailable
    }
    let state = TestModeUpdate.productsLoaded([product]).reduce(start)
    #expect(state.session?.products.map(\.identifier) == ["pro_monthly"])
    #expect(state.session?.entitlementIds == ["pro"])
    #expect(state.session?.freeTrialOverride == .forceAvailable)
  }

  @Test("purchased from untouched keeps the bought entitlements as subscribed")
  func purchasedFromUntouched() {
    let state = TestModeUpdate.purchased(entitlementIds: ["pro"]).reduce(activeState())
    let kept = state.session?.entitlements.kept ?? []
    #expect(kept.map(\.id) == ["pro"])
    #expect(kept.allSatisfy { $0.isActive && $0.state == .subscribed })
    guard case .active(let active) = state.session?.overriddenSubscriptionStatus else {
      Issue.record("Expected an active status")
      return
    }
    #expect(active.map(\.id) == ["pro"])
  }

  @Test("purchased keeps the other entitlements as the tester set them")
  func purchasedKeepsOthers() {
    let start = TestModeUpdate.restored([expiredPro]).reduce(activeState())
    let state = TestModeUpdate.purchased(entitlementIds: ["plus"]).reduce(start)
    let kept = state.session?.entitlements.kept ?? []
    #expect(Set(kept.map(\.id)) == ["pro", "plus"])
    #expect(kept.first { $0.id == "pro" }?.isActive == false)
    #expect(kept.first { $0.id == "pro" }?.state == .expired)
    #expect(kept.first { $0.id == "plus" }?.isActive == true)
  }

  @Test("purchased an entitlement already held as expired subscribes it")
  func purchasedResubscribes() {
    let start = TestModeUpdate.restored([expiredPro]).reduce(activeState())
    let state = TestModeUpdate.purchased(entitlementIds: ["pro"]).reduce(start)
    let kept = state.session?.entitlements.kept ?? []
    #expect(kept.count == 1)
    #expect(kept.first?.isActive == true)
    #expect(kept.first?.state == .subscribed)
  }

  @Test("settingsChosen sets the entitlements and the override")
  func settingsChosen() {
    let pro = Entitlement(id: "pro")
    let state = TestModeUpdate.settingsChosen(entitlements: [pro], freeTrialOverride: .forceUnavailable)
      .reduce(activeState())
    #expect(state.session?.entitlementIds == ["pro"])
    #expect(state.session?.freeTrialOverride == .forceUnavailable)
    #expect(state.session?.overriddenCustomerInfo?.entitlements == [pro])
    #expect(state.session?.overriddenSubscriptionStatus == .active([pro]))
  }

  @Test("settingsChosen then purchased adds to the choice and keeps the override")
  func settingsChosenThenPurchased() {
    let chosen = TestModeUpdate.settingsChosen(entitlements: [expiredPro], freeTrialOverride: .forceAvailable)
      .reduce(activeState())
    let state = TestModeUpdate.purchased(entitlementIds: ["plus"]).reduce(chosen)
    #expect(state.session?.entitlementIds == ["pro", "plus"])
    #expect(state.session?.freeTrialOverride == .forceAvailable)
    guard case .active(let active) = state.session?.overriddenSubscriptionStatus else {
      Issue.record("Expected an active status")
      return
    }
    #expect(active.filter(\.isActive).map(\.id) == ["plus"])
  }

  @Test("restored replaces the entitlements and leaves the override alone")
  func restored() {
    let start = activeState {
      $0.entitlements = .kept([Entitlement(id: "basic")])
      $0.freeTrialOverride = .forceAvailable
    }
    let pro = Entitlement(id: "pro")
    let state = TestModeUpdate.restored([pro]).reduce(start)
    #expect(state.session?.entitlementIds == ["pro"])
    #expect(state.session?.freeTrialOverride == .forceAvailable)
    #expect(state.session?.overriddenSubscriptionStatus == .active([pro]))
  }

  @Test("Only inactive entitlements are kept, but the status is inactive")
  func onlyInactiveEntitlements() {
    let state = TestModeUpdate.restored([expiredPro]).reduce(activeState())
    #expect(state.session?.entitlementIds == ["pro"])
    #expect(state.session?.overriddenCustomerInfo?.entitlements == [expiredPro])
    #expect(state.session?.overriddenSubscriptionStatus == .inactive)
    #expect(state.session?.hasActiveEntitlement == false)
  }

  @Test("Choosing nothing is kept apart from not having chosen yet")
  func choseNothingIsNotUntouched() {
    let untouched = activeState()
    let choseNothing = TestModeUpdate.restored([]).reduce(untouched)
    #expect(untouched.session?.overriddenSubscriptionStatus == nil)
    #expect(untouched.session?.overriddenCustomerInfo == nil)
    #expect(choseNothing.session?.overriddenSubscriptionStatus == .inactive)
    #expect(choseNothing.session?.overriddenCustomerInfo?.entitlements.isEmpty == true)
    #expect(choseNothing.session?.entitlementIds.isEmpty == true)
  }

  @Test("defaultsApplied keeps no entitlements")
  func defaultsApplied() {
    let start = activeState { $0.entitlements = .kept([Entitlement(id: "pro")]) }
    let state = TestModeUpdate.defaultsApplied.reduce(start)
    #expect(state.session?.entitlementIds.isEmpty == true)
    #expect(state.session?.overriddenSubscriptionStatus == .inactive)
  }
}

/// Records what actions ask for, against a store of its own.
private final class FakeTestModeContext: TestModeContext {
  enum Call: Equatable {
    case clearSavedSettings
    case saveHasActiveSubscription(Bool)
    case publishOverrides
    case publishTestModeEnded
  }

  let store = TestModeStore(initial: TestModeState())
  private(set) var calls: [Call] = []

  init(active: Bool = false) {
    if active {
      store.update(TestModeUpdate.activated(.testModeOption))
    }
  }

  @discardableResult
  func dispatch(_ action: TestModeAction) -> TestModeChange {
    store.dispatch(action, in: self)
  }

  func clearSavedSettings() { calls.append(.clearSavedSettings) }
  func saveHasActiveSubscription(_ hasActiveSubscription: Bool) {
    calls.append(.saveHasActiveSubscription(hasActiveSubscription))
  }
  func publishOverrides() { calls.append(.publishOverrides) }
  func publishTestModeEnded() { calls.append(.publishTestModeEnded) }
}

@Suite("TestModeAction")
struct TestModeActionTests {
  @Test("evaluated with a reason turns test mode on without side effects")
  func evaluatedOn() {
    let context = FakeTestModeContext()
    let change = context.dispatch(.evaluated(.configMatch))
    #expect(change.justActivated)
    #expect(!change.justDeactivated)
    #expect(context.calls.isEmpty)
  }

  @Test("evaluated again while on isn't a change")
  func evaluatedStillOn() {
    let context = FakeTestModeContext(active: true)
    let change = context.dispatch(.evaluated(.testModeOption))
    #expect(!change.justActivated)
    #expect(!change.justDeactivated)
    #expect(context.calls.isEmpty)
  }

  @Test("evaluated without a reason turns test mode off and hands the status back")
  func evaluatedOff() {
    let context = FakeTestModeContext(active: true)
    let change = context.dispatch(.evaluated(nil))
    #expect(change.justDeactivated)
    #expect(change.after.session == nil)
    #expect(context.calls == [.clearSavedSettings, .publishTestModeEnded])
  }

  @Test("evaluated without a reason while off only clears the saved settings")
  func evaluatedStillOff() {
    let context = FakeTestModeContext()
    let change = context.dispatch(.evaluated(nil))
    #expect(!change.justDeactivated)
    #expect(context.calls == [.clearSavedSettings])
  }

  @Test("productsLoaded has no side effects")
  func productsLoaded() {
    let context = FakeTestModeContext(active: true)
    context.dispatch(.productsLoaded([]))
    #expect(context.calls.isEmpty)
  }

  @Test("purchased publishes the overrides")
  func purchased() {
    let context = FakeTestModeContext(active: true)
    let change = context.dispatch(.purchased(entitlementIds: ["pro"]))
    #expect(change.after.session?.entitlementIds == ["pro"])
    #expect(context.calls == [.publishOverrides])
  }

  @Test("modalClosed saves whether a pick is active and publishes the overrides")
  func modalClosed() {
    let context = FakeTestModeContext(active: true)
    let change = context.dispatch(.modalClosed(
      entitlements: [Entitlement(id: "pro")],
      freeTrialOverride: .forceAvailable
    ))
    #expect(change.after.session?.freeTrialOverride == .forceAvailable)
    #expect(context.calls == [.saveHasActiveSubscription(true), .publishOverrides])

    context.dispatch(.modalClosed(entitlements: [expiredPro], freeTrialOverride: .useDefault))
    #expect(context.calls.suffix(2) == [.saveHasActiveSubscription(false), .publishOverrides])
  }

  @Test("restored publishes the overrides")
  func restored() {
    let context = FakeTestModeContext(active: true)
    context.dispatch(.restored([Entitlement(id: "pro")]))
    #expect(context.calls == [.publishOverrides])
  }

  @Test("defaultsApplied saves no active subscription and publishes the overrides")
  func defaultsApplied() {
    let context = FakeTestModeContext(active: true)
    context.dispatch(.defaultsApplied)
    #expect(context.calls == [.saveHasActiveSubscription(false), .publishOverrides])
  }

  @Test("Purchases, restores and defaults are dropped while test mode is off")
  func droppedWhileOff() {
    let context = FakeTestModeContext()
    context.dispatch(.purchased(entitlementIds: ["pro"]))
    context.dispatch(.restored([Entitlement(id: "pro")]))
    context.dispatch(.defaultsApplied)
    #expect(context.store.state.session == nil)
    #expect(context.calls.isEmpty)
  }

  @Test("Closing the modal after test mode turned off saves nothing and forgets the modal's own save")
  func modalClosedAfterTestModeTurnedOff() {
    // The modal is open when a config refresh takes the user out of test mode.
    let context = FakeTestModeContext(active: true)
    context.dispatch(.evaluated(nil))

    let change = context.dispatch(.modalClosed(
      entitlements: [Entitlement(id: "pro")],
      freeTrialOverride: .forceAvailable
    ))

    #expect(change.after.session == nil)
    #expect(!context.calls.contains(.saveHasActiveSubscription(true)))
    #expect(!context.calls.dropFirst(2).contains(.publishOverrides))
    #expect(context.calls.last == .clearSavedSettings)
  }
}

/// Records what ``TestModeManager`` sends to the rest of the SDK.
private final class RecordingStatusSink: TestModeStatusSink, @unchecked Sendable {
  enum Sent: Equatable {
    case overrides(SubscriptionStatus)
    case testModeEnded
  }

  private let lock = NSLock()
  private var _sent: [Sent] = []

  var sent: [Sent] {
    lock.lock()
    defer { lock.unlock() }
    return _sent
  }

  func send(customerInfo: CustomerInfo, status: SubscriptionStatus) {
    lock.lock()
    _sent.append(.overrides(status))
    lock.unlock()
  }

  func sendTestModeEnded() {
    lock.lock()
    _sent.append(.testModeEnded)
    lock.unlock()
  }
}

@Suite("TestModeManager store")
struct TestModeManagerStoreTests {
  /// The container owns what the manager holds unowned references to, so
  /// tests keep it alive until they finish.
  private func makeManager(
    defaults: UserDefaults = .standard,
    sink: TestModeStatusSink = RecordingStatusSink()
  ) -> (TestModeManager, DependencyContainer) {
    let dependencyContainer = DependencyContainer()
    let manager = TestModeManager(
      identityManager: dependencyContainer.identityManager,
      deviceHelper: dependencyContainer.deviceHelper,
      storage: dependencyContainer.storage,
      defaults: defaults,
      statusSink: sink
    )
    return (manager, dependencyContainer)
  }

  private var alwaysOn: SuperwallOptions {
    let options = SuperwallOptions()
    options.testModeBehavior = .always
    return options
  }

  @Test("A purchase still being sent when test mode turns off doesn't become the real status")
  @MainActor
  func purchaseSentAfterTestModeTurnedOff() async {
    let sink = RecordingStatusSink()
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let (manager, container) = makeManager(defaults: isolated.defaults, sink: sink)
    manager.evaluateTestMode(config: .stub(), options: alwaysOn)

    // On the main actor, as the purchase drawer is: the send can't run before
    // the config refresh below turns test mode off.
    manager.dispatch(.purchased(entitlementIds: ["pro"]))
    manager.evaluateTestMode(config: .stub(), options: SuperwallOptions())
    await manager.finishPublishing()

    #expect(sink.sent == [.testModeEnded])
    withExtendedLifetime(container) {}
  }

  @Test("Sends go out in order with the state at send time")
  @MainActor
  func sendsUseTheLatestState() async {
    let sink = RecordingStatusSink()
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let (manager, container) = makeManager(defaults: isolated.defaults, sink: sink)
    manager.evaluateTestMode(config: .stub(), options: alwaysOn)

    manager.dispatch(.restored([expiredPro]))
    manager.dispatch(.purchased(entitlementIds: ["plus"]))
    await manager.finishPublishing()

    guard sink.sent.count == 2, case .overrides(.active(let entitlements)) = sink.sent.last else {
      Issue.record("Expected two active sends, got \(sink.sent)")
      return
    }
    #expect(sink.sent.first == sink.sent.last)
    #expect(entitlements.filter(\.isActive).map(\.id) == ["plus"])
    withExtendedLifetime(container) {}
  }

  @Test("Purchases made at the same time on many threads are all kept")
  func concurrentPurchasesAreAllKept() async {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let (manager, container) = makeManager(defaults: isolated.defaults)
    manager.evaluateTestMode(config: .stub(), options: alwaysOn)
    let ids = (0..<200).map { "entitlement_\($0)" }

    await withTaskGroup(of: Void.self) { group in
      for id in ids {
        group.addTask {
          manager.dispatch(.purchased(entitlementIds: [id]))
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
    await manager.finishPublishing()
    withExtendedLifetime(container) {}
  }

  @Test("Observers hear 200 concurrent updates in the order they were applied")
  func observersHearUpdatesInOrder() async {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let (manager, container) = makeManager(defaults: isolated.defaults)
    manager.evaluateTestMode(config: .stub(), options: alwaysOn)
    let counts = LockedArray()
    manager.store.observe { before, after in
      counts.append((before.session?.entitlementIds.count ?? -1, after.session?.entitlementIds.count ?? -1))
    }

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 {
        group.addTask {
          manager.dispatch(.purchased(entitlementIds: ["e\(index)"]))
        }
      }
    }

    let heard = counts.values
    #expect(heard.count == 200)
    for (offset, pair) in heard.enumerated() {
      #expect(pair.0 == offset)
      #expect(pair.1 == offset + 1)
    }
    await manager.finishPublishing()
    withExtendedLifetime(container) {}
  }

  @Test("Turning test mode off forgets the session and the saved settings")
  func deactivationForgetsEverything() async {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let (manager, container) = makeManager(defaults: isolated.defaults)
    let storage = container.storage!
    manager.evaluateTestMode(config: .stub(), options: alwaysOn)
    manager.dispatch(.modalClosed(entitlements: [Entitlement(id: "pro")], freeTrialOverride: .forceAvailable))
    TestModeSettingsStore.save(
      ["pro": EntitlementSelection(state: .subscribed, offerType: nil)],
      freeTrialOverride: .forceAvailable,
      in: isolated.defaults
    )
    #expect(storage.get(IsTestModeActiveSubscription.self) == true)

    let change = manager.evaluateTestMode(config: .stub(), options: SuperwallOptions())

    #expect(change.justDeactivated)
    #expect(manager.state.session == nil)
    #expect(manager.products.isEmpty)
    #expect(manager.testEntitlementIds.isEmpty)
    #expect(manager.freeTrialOverride == .useDefault)
    #expect(manager.overriddenSubscriptionStatus == nil)
    #expect(manager.overriddenCustomerInfo == nil)
    #expect(TestModeSettingsStore.loadSelections(from: isolated.defaults).isEmpty)
    #expect(isolated.defaults.object(forKey: TestModeSettingsStore.freeTrialOverrideKey) == nil)
    #expect(storage.get(IsTestModeActiveSubscription.self) == false)
    await manager.finishPublishing()
    withExtendedLifetime(container) {}
  }

  @Test("Closing the modal after test mode turned off leaves no saved active subscription")
  func modalClosedAfterTestModeTurnedOff() async {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let (manager, container) = makeManager(defaults: isolated.defaults)
    let storage = container.storage!
    manager.evaluateTestMode(config: .stub(), options: alwaysOn)
    manager.evaluateTestMode(config: .stub(), options: SuperwallOptions())
    // The modal saves the tester's picks as it closes.
    TestModeSettingsStore.save(
      ["pro": EntitlementSelection(state: .subscribed, offerType: nil)],
      freeTrialOverride: .forceAvailable,
      in: isolated.defaults
    )

    manager.dispatch(.modalClosed(entitlements: [Entitlement(id: "pro")], freeTrialOverride: .forceAvailable))

    #expect((storage.get(IsTestModeActiveSubscription.self) ?? false) == false)
    #expect(TestModeSettingsStore.loadSelections(from: isolated.defaults).isEmpty)
    #expect(manager.overriddenSubscriptionStatus == nil)
    await manager.finishPublishing()
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
