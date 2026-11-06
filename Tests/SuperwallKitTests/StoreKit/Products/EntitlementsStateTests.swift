//
//  EntitlementsStateTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Combine
import Testing
import Foundation

private func entitlement(_ id: String, isActive: Bool = true) -> Entitlement {
  return Entitlement(id: id, type: .serviceLevel, isActive: isActive)
}

private func status(_ id: String) -> SubscriptionStatus {
  return .active([entitlement(id)])
}

// MARK: - Reducers

struct EntitlementsStateReducerTests {
  private func reduce(
    _ updates: [EntitlementsUpdate],
    from state: EntitlementsState = EntitlementsState()
  ) -> EntitlementsState {
    return updates.reduce(state) { $1.reduce($0) }
  }

  @Test func productEntitlementsReceived_replacesTheMap_andDerivesAllAndInactive() {
    let pro = entitlement("pro")
    let basic = entitlement("basic")
    var state = reduce([
      .productEntitlementsReceived(["a": [pro], "b": [basic]]),
      .sdkAssignedStatus(.active([pro]), testMode: .off)
    ])

    #expect(state.all == [pro, basic])
    #expect(state.active == [pro])
    #expect(state.inactive == [basic])
    #expect(state.byProductId("a") == [pro])
    #expect(state.byProductId("missing").isEmpty)
    #expect(state.byProductIds(["a", "b", "missing"]) == [pro, basic])

    state = reduce([.productEntitlementsReceived(["b": [basic]])], from: state)
    #expect(state.byProductId("a").isEmpty)
    #expect(state.all == [basic])
  }

  @Test func sdkAssignedStatus_isPublishedAsAssigned() {
    let pro = entitlement("pro")
    let state = reduce([.sdkAssignedStatus(.active([pro]), testMode: .off)])
    #expect(state.assignedStatus == .active([pro]))
    #expect(state.status == .active([pro]))
    #expect(state.active == [pro])
  }

  @Test func emptyActive_publishesAsInactive_butIsAssignedAsGiven() {
    let state = reduce([.sdkAssignedStatus(.active([]), testMode: .off)])
    #expect(state.assignedStatus == .active([]))
    #expect(state.status == .inactive)
    #expect(state.active.isEmpty)
  }

  @Test func activeGrants_mergeIntoInactive_butNotIntoUnknown() {
    let grant = entitlement("granted")
    var state = reduce([.grantsChanged([grant], testMode: .off)])
    #expect(state.status == .unknown)
    #expect(state.granted == [grant])

    state = reduce([.sdkAssignedStatus(.inactive, testMode: .off)], from: state)
    #expect(state.assignedStatus == .inactive)
    #expect(state.status == .active([grant]))

    state = reduce([.grantsChanged([], testMode: .off)], from: state)
    #expect(state.status == .inactive)
  }

  @Test func inactiveGrants_dontMerge() {
    let state = reduce([
      .grantsChanged([entitlement("granted", isActive: false)], testMode: .off),
      .sdkAssignedStatus(.inactive, testMode: .off)
    ])
    #expect(state.status == .inactive)
  }

  @Test func activeAssigned_andActiveGrantWithTheSameId_publishOneRecord() {
    let device = Entitlement(
      id: "pro",
      type: .serviceLevel,
      isActive: true,
      productIds: ["com.example.monthly"],
      store: .appStore,
      expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let grant = entitlement("pro")
    let state = reduce([
      .grantsChanged([grant], testMode: .off),
      .sdkAssignedStatus(.active([device]), testMode: .off)
    ])
    #expect(state.active.count == 1)
    #expect(state.active == Entitlement.mergePrioritized([device, grant]))
    #expect(state.assignedStatus == .active([device]))
  }

  @Test func developerAssignment_stripsGrantedRecords() {
    let grant = entitlement("granted")
    let own = entitlement("own")
    let state = reduce([
      .grantsChanged([grant], testMode: .off),
      .developerAssignedStatus(.active([grant, own]), testMode: .off)
    ])
    #expect(state.assignedStatus == .active([own]))
    #expect(state.status == .active([grant, own]))
  }

  @Test func developerAssigningOnlyGrants_thenClearingThem_publishesInactive() {
    let grant = entitlement("granted")
    var state = reduce([
      .grantsChanged([grant], testMode: .off),
      .developerAssignedStatus(.active([grant]), testMode: .off)
    ])
    #expect(state.assignedStatus == .active([]))
    #expect(state.status == .active([grant]))

    state = reduce([.grantsChanged([], testMode: .off)], from: state)
    #expect(state.status == .inactive)
  }

  @Test func developerUnknown_withGrants_staysUnknown() {
    let state = reduce([
      .grantsChanged([entitlement("granted")], testMode: .off),
      .developerAssignedStatus(.unknown, testMode: .off)
    ])
    #expect(state.assignedStatus == .unknown)
    #expect(state.status == .unknown)
    #expect(state.grantWarning == .notDue)
  }

  @Test func developerInactive_withActiveGrants_logsTheWarningOnce() {
    var state = reduce([.developerAssignedStatus(.inactive, testMode: .off)])
    #expect(state.grantWarning == .notDue)

    state = reduce([
      .grantsChanged([entitlement("granted")], testMode: .off),
      .sdkAssignedStatus(.inactive, testMode: .off)
    ], from: state)
    #expect(state.grantWarning == .notDue)

    state = reduce([.developerAssignedStatus(.inactive, testMode: .off)], from: state)
    #expect(state.grantWarning == .logged)

    state = reduce([.grantsChanged([], testMode: .off)], from: state)
    #expect(state.grantWarning == .logged)
  }

  @Test func testModeOverride_replacesThePublishedStatus() {
    let pro = entitlement("pro")
    let state = reduce([
      .grantsChanged([entitlement("granted")], testMode: .off),
      .sdkAssignedStatus(.inactive, testMode: .overriding(.active([pro])))
    ])
    #expect(state.assignedStatus == .inactive)
    #expect(state.status == .active([pro]))
  }

  @Test func testModeOverride_isKeptByAGrantChange() {
    let state = reduce([
      .sdkAssignedStatus(.inactive, testMode: .overriding(status("simulated"))),
      .grantsChanged([entitlement("granted")], testMode: .overriding(status("simulated")))
    ])
    #expect(state.status == status("simulated"))
  }

  @Test func publishingWithoutAnOverride_fallsBackToTheMerge() {
    let grant = entitlement("granted")
    let state = reduce([
      .grantsChanged([grant], testMode: .off),
      .sdkAssignedStatus(.inactive, testMode: .overriding(status("simulated"))),
      .sdkAssignedStatus(.inactive, testMode: .off)
    ])
    #expect(state.testMode == .off)
    #expect(state.status == .active([grant]))
  }

  @Test func testModeOverride_isBuiltFromAnOptional() {
    #expect(TestModeOverride(nil) == .off)
    #expect(TestModeOverride(.inactive) == .overriding(.inactive))
  }
}

// MARK: - Actions

/// Records every side effect an action asks for.
private final class FakeEntitlementsContext: EntitlementsContext {
  enum Call: Equatable {
    case saveProductMap([String: Set<Entitlement>])
    case saveGranted(Set<Entitlement>)
    case saveAssignedStatus(SubscriptionStatus)
    case logGrantWarning(storeLocked: Bool)
    case queuePublication(SubscriptionStatus)
    case deliverPublications(storeLocked: Bool)
  }

  let store = EntitlementsStore(initial: EntitlementsState())
  let override = Locked<SubscriptionStatus?>(nil)
  let calls = Locked<[Call]>([])
  /// Called while the override is read, with the store locked.
  var onReadOverride: (() -> Void)?

  func currentTestModeOverride() -> SubscriptionStatus? {
    onReadOverride?()
    return override.value
  }

  func saveProductMap(_ entitlementsByProductId: [String: Set<Entitlement>]) {
    calls.mutate { $0.append(.saveProductMap(entitlementsByProductId)) }
  }

  func saveGranted(_ granted: Set<Entitlement>) {
    calls.mutate { $0.append(.saveGranted(granted)) }
  }

  func saveAssignedStatus(_ status: SubscriptionStatus) {
    calls.mutate { $0.append(.saveAssignedStatus(status)) }
  }

  func logGrantWarning() {
    let locked = isStoreLocked()
    calls.mutate { $0.append(.logGrantWarning(storeLocked: locked)) }
  }

  func queuePublication(_ publication: EntitlementsPublication) {
    calls.mutate { $0.append(.queuePublication(publication.after.status)) }
  }

  func deliverPublications() {
    let locked = isStoreLocked()
    calls.mutate { $0.append(.deliverPublications(storeLocked: locked)) }
  }

  /// Whether another thread is kept from reading the store.
  private func isStoreLocked() -> Bool {
    let read = DispatchSemaphore(value: 0)
    DispatchQueue.global().async { [store] in
      _ = store.state
      read.signal()
    }
    return read.wait(timeout: .now() + 0.2) == .timedOut
  }

  @discardableResult
  func dispatch(_ action: EntitlementsAction) -> EntitlementsState {
    return store.dispatch(action, in: self)
  }
}

struct EntitlementsActionTests {
  @Test func changeStatus_savesWhatChanged_andPublishesOnceUnlocked() {
    let context = FakeEntitlementsContext()
    let grant = entitlement("granted")

    let after = context.dispatch(.changeStatus(.grantChange([grant])))
    #expect(after.granted == [grant])
    #expect(context.calls.value == [
      .saveGranted([grant]),
      .queuePublication(.unknown),
      .deliverPublications(storeLocked: false)
    ])

    context.calls.mutate { $0 = [] }
    context.dispatch(.changeStatus(.sdkAssignment(.inactive)))
    #expect(context.calls.value == [
      .saveAssignedStatus(.inactive),
      .queuePublication(.active([grant])),
      .deliverPublications(storeLocked: false)
    ])

    // Nothing changed, so nothing is saved, but it's still published.
    context.calls.mutate { $0 = [] }
    context.dispatch(.changeStatus(.sdkAssignment(.inactive)))
    #expect(context.calls.value == [
      .queuePublication(.active([grant])),
      .deliverPublications(storeLocked: false)
    ])
  }

  @Test func changeStatus_logsTheGrantWarningOnce_withTheStoreUnlocked() {
    let context = FakeEntitlementsContext()
    context.dispatch(.changeStatus(.grantChange([entitlement("granted")])))
    context.calls.mutate { $0 = [] }

    context.dispatch(.changeStatus(.developerAssignment(.inactive)))
    #expect(context.calls.value.contains(.logGrantWarning(storeLocked: false)))

    context.calls.mutate { $0 = [] }
    context.dispatch(.changeStatus(.developerAssignment(.inactive)))
    #expect(!context.calls.value.contains(.logGrantWarning(storeLocked: false)))
  }

  @Test func changeStatus_recordsTheTestModeOverride() {
    let context = FakeEntitlementsContext()
    context.override.mutate { $0 = status("simulated") }
    let overridden = context.dispatch(.changeStatus(.sdkAssignment(.inactive)))
    #expect(overridden.testMode == .overriding(status("simulated")))
    #expect(overridden.status == status("simulated"))

    context.override.mutate { $0 = nil }
    let merged = context.dispatch(.changeStatus(.sdkAssignment(.inactive)))
    #expect(merged.status == .inactive)
  }

  @Test func receiveProductEntitlements_savesOnlyAChange_andPublishesNothing() {
    let context = FakeEntitlementsContext()
    let map = ["product": Set([entitlement("pro")])]

    let after = context.dispatch(.receiveProductEntitlements(map))
    #expect(after.entitlementsByProductId == map)
    #expect(context.calls.value == [.saveProductMap(map)])

    context.dispatch(.receiveProductEntitlements(map))
    #expect(context.calls.value == [.saveProductMap(map)])
  }

  /// A publish on another thread can't land between reading the test-mode
  /// override and applying it, so an older override is never published after
  /// a newer one.
  @Test func testModeOverride_isReadWithTheStoreLocked() {
    let context = FakeEntitlementsContext()
    context.override.mutate { $0 = .inactive }
    let firstIsReading = DispatchSemaphore(value: 0)
    let secondReturned = DispatchSemaphore(value: 0)
    let secondReturnedWhileFirstRead = Locked(false)
    let firstReturned = DispatchSemaphore(value: 0)
    let isFirstRead = Locked(true)
    context.onReadOverride = {
      let isFirst = isFirstRead.value
      isFirstRead.mutate { $0 = false }
      if !isFirst {
        return
      }
      firstIsReading.signal()
      // A simulated purchase on another thread changes the override and
      // publishes. It has to wait for this publish to finish.
      let returned = secondReturned.wait(timeout: .now() + 0.3) == .success
      secondReturnedWhileFirstRead.mutate { $0 = returned }
    }

    DispatchQueue.global().async {
      context.dispatch(.changeStatus(.sdkAssignment(.unknown)))
      firstReturned.signal()
    }

    #expect(firstIsReading.wait(timeout: .now() + 2) == .success)
    context.override.mutate { $0 = status("simulated") }
    context.dispatch(.changeStatus(.sdkAssignment(.unknown)))
    secondReturned.signal()

    #expect(firstReturned.wait(timeout: .now() + 2) == .success)
    #expect(!secondReturnedWhileFirstRead.value)
    #expect(context.store.state.status == status("simulated"))
  }

  /// However the writers interleave, the last override set is the one
  /// published.
  @Test func concurrentOverrideChanges_publishTheLatestOverride() {
    let context = FakeEntitlementsContext()
    DispatchQueue.concurrentPerform(iterations: 200) { index in
      context.override.mutate { $0 = status("e\(index)") }
      context.dispatch(.changeStatus(.sdkAssignment(.inactive)))
    }
    #expect(context.store.state.status == context.override.value)
  }
}

// MARK: - EntitlementsInfo

/// Records what ``EntitlementsInfo`` hands over.
private final class RecordingPublisher: EntitlementsPublishing {
  let override = Locked<SubscriptionStatus?>(nil)
  let received = Locked<[EntitlementsPublication]>([])
  var onPublish: ((EntitlementsPublication) -> Void)?

  func currentTestModeOverride() -> SubscriptionStatus? {
    return override.value
  }

  func entitlementsDidPublish(_ publication: EntitlementsPublication) {
    received.mutate { $0.append(publication) }
    onPublish?(publication)
  }
}

@Suite(.serialized)
final class EntitlementsInfoStoreTests {
  private let dependencyContainer = DependencyContainer(cache: CacheMock())

  private func makeInfo(isTesting: Bool = false) -> EntitlementsInfo {
    return EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: isTesting
    )
  }

  @Test func activeMatchesTheStatus_asSoonAsItsPublished() {
    let info = makeInfo()
    for index in 0..<50 {
      info.publish(.sdkAssignment(status("e\(index)")))
      #expect(info.active.map(\.id) == ["e\(index)"])
    }
    info.publish(.sdkAssignment(.inactive))
    #expect(info.active.isEmpty)
  }

  @Test func allMatchesTheConfig_asSoonAsItsSet() {
    let info = makeInfo()
    let pro = Entitlement(id: "pro")
    info.setEntitlementsFromConfig(["product": [pro]])
    #expect(info.all == [pro])
    #expect(info.byProductId("product") == [pro])
  }

  @Test func changes_areSaved_andLoadedByTheNextInstance() {
    let grant = Entitlement(id: "granted")
    let pro = Entitlement(id: "pro")
    let info = makeInfo()
    info.setEntitlementsFromConfig(["product": [pro]])
    info.publish(.grantChange([grant]))
    info.publish(.sdkAssignment(.inactive))

    let storage: Storage = dependencyContainer.storage
    #expect(storage.get(EntitlementsByProductId.self) == ["product": [pro]])
    #expect(storage.get(GrantedEntitlements.self) == [grant])
    // The assigned value is saved, not the one with grants merged in.
    #expect(storage.get(SubscriptionStatusKey.self) == .inactive)

    let reloaded = makeInfo()
    #expect(reloaded.all == [pro])
    #expect(reloaded.granted == [grant])

    info.publish(.grantChange([]))
    info.setEntitlementsFromConfig([:])
  }

  @Test func publications_reachThePublisherInTheOrderTheyWereApplied() {
    let info = makeInfo(isTesting: true)
    let publisher = RecordingPublisher()
    info.publisher = publisher
    let applied = Locked<[SubscriptionStatus]>([])
    info.store.observe { before, after in
      if before.status != after.status {
        applied.mutate { $0.append(after.status) }
      }
    }

    DispatchQueue.concurrentPerform(iterations: 200) { index in
      info.publish(.sdkAssignment(status("e\(index)")))
    }

    let received = publisher.received.value.map(\.after.status)
    #expect(applied.value.count == 200)
    #expect(received == applied.value)
    #expect(received.last == info.status)
  }

  @Test func publisher_runsWithTheStoreUnlocked() {
    let info = makeInfo(isTesting: true)
    let publisher = RecordingPublisher()
    info.publisher = publisher
    let readFinished = Locked(false)
    publisher.onPublish = { _ in
      let otherThreadRead = DispatchSemaphore(value: 0)
      DispatchQueue.global().async {
        _ = info.status
        otherThreadRead.signal()
      }
      // Waiting here would deadlock if the store were still locked.
      readFinished.mutate { $0 = otherThreadRead.wait(timeout: .now() + 2) == .success }
    }

    info.publish(.sdkAssignment(status("pro")))
    #expect(readFinished.value)
  }

  @Test func publisher_suppliesTheTestModeOverride() {
    let info = makeInfo(isTesting: true)
    let publisher = RecordingPublisher()
    info.publisher = publisher
    publisher.override.mutate { $0 = status("simulated") }
    info.publish(.sdkAssignment(.inactive))
    #expect(info.status == status("simulated"))
  }

  @Test func superwall_activeEntitlementsFollowTheStatus() {
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let received = Locked<[SubscriptionStatus]>([])
    let cancellable = superwall.$subscriptionStatus
      .dropFirst()
      .sink { status in received.mutate { $0.append(status) } }

    superwall.subscriptionStatus = status("pro")
    #expect(superwall.entitlements.active.map(\.id) == ["pro"])
    #expect(received.value == [status("pro")])

    superwall.grantedEntitlements = [Entitlement(id: "granted")]
    superwall.subscriptionStatus = .inactive
    #expect(superwall.assignedSubscriptionStatus == .inactive)
    #expect(superwall.entitlements.active.map(\.id) == ["granted"])
    #expect(received.value.last == superwall.subscriptionStatus)

    superwall.grantedEntitlements = []
    #expect(superwall.subscriptionStatus == .inactive)
    #expect(superwall.entitlements.active.isEmpty)
    cancellable.cancel()
  }
}

/// A value guarded by a lock, for collecting values off arbitrary threads.
private final class Locked<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: Value

  init(_ value: Value) {
    storage = value
  }

  var value: Value {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  func mutate(_ body: (inout Value) -> Void) {
    lock.lock()
    body(&storage)
    lock.unlock()
  }
}
