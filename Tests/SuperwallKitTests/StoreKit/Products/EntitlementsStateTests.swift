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

// MARK: - Reducers

struct EntitlementsStateReducerTests {
  private func entitlement(_ id: String, isActive: Bool = true) -> Entitlement {
    return Entitlement(id: id, type: .serviceLevel, isActive: isActive)
  }

  private func reduce(
    _ updates: [EntitlementsUpdate],
    from state: EntitlementsState = EntitlementsState()
  ) -> EntitlementsState {
    return updates.reduce(state) { $1.reduce($0) }
  }

  @Test func productEntitlements_replaceTheMap_andDeriveAllAndInactive() {
    let pro = entitlement("pro")
    let basic = entitlement("basic")
    var state = reduce([.productEntitlements(["a": [pro], "b": [basic]])])
    state = reduce([.publish(.sdkAssignment(.active([pro])), testModeOverride: nil)], from: state)

    #expect(state.all == [pro, basic])
    #expect(state.active == [pro])
    #expect(state.inactive == [basic])
    #expect(state.byProductId("a") == [pro])
    #expect(state.byProductId("missing").isEmpty)
    #expect(state.byProductIds(["a", "b", "missing"]) == [pro, basic])

    state = reduce([.productEntitlements(["b": [basic]])], from: state)
    #expect(state.byProductId("a").isEmpty)
    #expect(state.all == [basic])
  }

  @Test func sdkAssignment_setsBothStatuses() {
    let pro = entitlement("pro")
    let state = reduce([.publish(.sdkAssignment(.active([pro])), testModeOverride: nil)])
    #expect(state.assignedStatus == .active([pro]))
    #expect(state.status == .active([pro]))
    #expect(state.active == [pro])
  }

  @Test func emptyActive_publishesAsInactive_butIsAssignedAsGiven() {
    let state = reduce([.publish(.sdkAssignment(.active([])), testModeOverride: nil)])
    #expect(state.assignedStatus == .active([]))
    #expect(state.status == .inactive)
    #expect(state.active.isEmpty)
  }

  @Test func activeGrants_mergeIntoInactive_butNotIntoUnknown() {
    let grant = entitlement("granted")
    var state = reduce([.publish(.grantChange([grant]), testModeOverride: nil)])
    #expect(state.status == .unknown)
    #expect(state.granted == [grant])

    state = reduce([.publish(.sdkAssignment(.inactive), testModeOverride: nil)], from: state)
    #expect(state.assignedStatus == .inactive)
    #expect(state.status == .active([grant]))

    state = reduce([.publish(.grantChange([]), testModeOverride: nil)], from: state)
    #expect(state.status == .inactive)
  }

  @Test func inactiveGrants_dontMerge() {
    let state = reduce([
      .publish(.grantChange([entitlement("granted", isActive: false)]), testModeOverride: nil),
      .publish(.sdkAssignment(.inactive), testModeOverride: nil)
    ])
    #expect(state.status == .inactive)
  }

  @Test func developerAssignment_stripsGrantedRecords() {
    let grant = entitlement("granted")
    let own = entitlement("own")
    let state = reduce([
      .publish(.grantChange([grant]), testModeOverride: nil),
      .publish(.developerAssignment(.active([grant, own])), testModeOverride: nil)
    ])
    #expect(state.assignedStatus == .active([own]))
    #expect(state.status == .active([grant, own]))
  }

  @Test func developerInactive_withActiveGrants_flagsTheWarning() {
    var state = reduce([.publish(.developerAssignment(.inactive), testModeOverride: nil)])
    #expect(!state.hasGrantedEntitlementsWarning)

    state = reduce([
      .publish(.grantChange([entitlement("granted")]), testModeOverride: nil),
      .publish(.sdkAssignment(.inactive), testModeOverride: nil)
    ], from: state)
    #expect(!state.hasGrantedEntitlementsWarning)

    state = reduce([.publish(.developerAssignment(.inactive), testModeOverride: nil)], from: state)
    #expect(state.hasGrantedEntitlementsWarning)
  }

  @Test func testModeOverride_replacesThePublishedStatus() {
    let pro = entitlement("pro")
    let state = reduce([
      .publish(.grantChange([entitlement("granted")]), testModeOverride: nil),
      .publish(.sdkAssignment(.inactive), testModeOverride: .active([pro]))
    ])
    #expect(state.assignedStatus == .inactive)
    #expect(state.status == .active([pro]))
  }
}

// MARK: - EntitlementsInfo

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

  private func status(_ id: String) -> SubscriptionStatus {
    return .active([Entitlement(id: id, type: .serviceLevel, isActive: true)])
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

  @Test func publishedStatuses_reachTheReceiverInTheOrderTheyWereApplied() {
    let info = makeInfo(isTesting: true)
    let applied = Locked<[SubscriptionStatus]>([])
    let received = Locked<[SubscriptionStatus]>([])
    // Observers run in the order updates are applied.
    info.store.observe { before, after in
      if before.status != after.status {
        applied.mutate { $0.append(after.status) }
      }
    }
    info.publishStatusChanges { status in
      received.mutate { $0.append(status) }
    }

    DispatchQueue.concurrentPerform(iterations: 200) { index in
      info.publish(.sdkAssignment(self.status("e\(index)")))
    }

    #expect(applied.value.count == 200)
    #expect(received.value == applied.value)
    #expect(received.value.last == info.status)
  }

  @Test func receiver_runsWithTheStoreUnlocked() {
    let info = makeInfo(isTesting: true)
    let otherThreadRead = DispatchSemaphore(value: 0)
    let readFinished = Locked(false)
    info.publishStatusChanges { _ in
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

  /// A publish on another thread can't land between reading the test-mode
  /// override and applying it, so an older override is never published after
  /// a newer one.
  @Test func testModeOverride_isReadWithTheStoreLocked() {
    let info = makeInfo(isTesting: true)
    let override = Locked<SubscriptionStatus?>(.inactive)
    let firstIsReading = DispatchSemaphore(value: 0)
    let secondReturned = DispatchSemaphore(value: 0)
    let secondReturnedWhileFirstRead = Locked(false)
    let firstReturned = DispatchSemaphore(value: 0)

    DispatchQueue.global().async {
      info.publish(.sdkAssignment(.unknown)) {
        firstIsReading.signal()
        // A simulated purchase on another thread changes the override and
        // publishes. It has to wait for this publish to finish.
        let returned = secondReturned.wait(timeout: .now() + 0.3) == .success
        secondReturnedWhileFirstRead.mutate { $0 = returned }
        return override.value
      }
      firstReturned.signal()
    }

    #expect(firstIsReading.wait(timeout: .now() + 2) == .success)
    override.mutate { $0 = self.status("simulated") }
    info.publish(.sdkAssignment(.unknown)) { override.value }
    secondReturned.signal()

    #expect(firstReturned.wait(timeout: .now() + 2) == .success)
    #expect(!secondReturnedWhileFirstRead.value)
    #expect(info.status == status("simulated"))
  }

  /// However the writers interleave, the last override set is the one
  /// published.
  @Test func concurrentOverrideChanges_publishTheLatestOverride() {
    let info = makeInfo(isTesting: true)
    let override = Locked<SubscriptionStatus?>(nil)
    DispatchQueue.concurrentPerform(iterations: 200) { index in
      override.mutate { $0 = self.status("e\(index)") }
      info.publish(.sdkAssignment(.inactive)) { override.value }
    }
    #expect(info.status == override.value)
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
