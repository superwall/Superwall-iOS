//
//  EntitlementsPublishingTests.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Combine
import Testing
import Foundation

/// What `Superwall` sends out after an entitlements change: customer info and
/// the status-change event.
@Suite(.serialized)
final class EntitlementsPublishingTests {
  private func appStoreEntitlement(_ id: String) -> Entitlement {
    return Entitlement(id: id, type: .serviceLevel, isActive: true, store: .appStore)
  }

  private func activeIds(_ info: CustomerInfo) -> [String] {
    return info.entitlements.filter(\.isActive).map(\.id).sorted()
  }

  /// A `$customerInfo` subscriber that changes the status hears the newer
  /// customer info, and the value left at the end matches the status.
  @Test func customerInfo_matchesTheLatestStatus_whenASubscriberChangesIt() {
    let dependencyContainer = DependencyContainer(
      purchaseController: MockPurchaseController(),
      cache: CacheMock()
    )
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    var hasChangedStatus = false
    let cancellable = superwall.$customerInfo
      .dropFirst()
      .sink { [unowned superwall] _ in
        if hasChangedStatus {
          return
        }
        hasChangedStatus = true
        superwall.subscriptionStatus = .active([self.appStoreEntitlement("plus")])
      }

    superwall.subscriptionStatus = .active([appStoreEntitlement("pro")])

    #expect(superwall.subscriptionStatus == .active([appStoreEntitlement("plus")]))
    #expect(activeIds(superwall.customerInfo) == ["plus"])
    cancellable.cancel()
  }

  /// A change made in test mode can be handed over after test mode has turned
  /// off. Its status is test mode's, so it mustn't become the customer info.
  @Test func changeMadeInTestMode_handedOverAfterItEnds_leavesCustomerInfoAlone() {
    let dependencyContainer = DependencyContainer(
      purchaseController: MockPurchaseController(),
      cache: CacheMock()
    )
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    superwall.subscriptionStatus = .active([appStoreEntitlement("pro")])
    #expect(activeIds(superwall.customerInfo) == ["pro"])

    let before = superwall.entitlements.store.state
    var after = before
    after.testMode = .overriding(.active([appStoreEntitlement("test")]))
    #expect(dependencyContainer.testModeManager.isTestMode == false)

    superwall.entitlementsDidPublish(
      EntitlementsPublication(
        change: .sdkAssignment(.active([appStoreEntitlement("pro")])),
        before: before,
        after: after
      )
    )

    #expect(activeIds(superwall.customerInfo) == ["pro"])
  }

  /// Test mode writes its override on one thread while a status change reads
  /// it on another.
  @Test func testModeOverride_isReadWhileItsWritten() async {
    let options = SuperwallOptions()
    options.testModeBehavior = .always
    let dependencyContainer = DependencyContainer(options: options, cache: CacheMock())
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeManager: TestModeManager = dependencyContainer.testModeManager
    testModeManager.evaluateTestMode(config: .stub(), options: options)
    let statuses: [SubscriptionStatus] = [
      .inactive,
      .active([appStoreEntitlement("pro")]),
      .active([appStoreEntitlement("pro"), appStoreEntitlement("plus")])
    ]

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<500 {
        group.addTask {
          testModeManager.overriddenSubscriptionStatus = statuses[index % statuses.count]
        }
        group.addTask {
          _ = superwall.currentTestModeOverride()
        }
      }
    }

    testModeManager.overriddenSubscriptionStatus = .inactive
    #expect(superwall.currentTestModeOverride() == .inactive)
  }

  /// The status-change event lists the grants that were in place when that
  /// status was published, not the ones in place when the event is sent.
  @MainActor
  @Test func statusChangeEvent_pairsTheStatusWithItsOwnGrants() async throws {
    let dependencyContainer = DependencyContainer(cache: CacheMock())
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let delegate = MockSuperwallDelegate()
    dependencyContainer.delegateAdapter.swiftDelegate = delegate
    superwall.listenToSubscriptionStatus()

    let grant = Entitlement(id: "granted")
    superwall.grantedEntitlements = [grant]
    superwall.subscriptionStatus = .inactive
    superwall.grantedEntitlements = []

    var statusEvents: [SuperwallEventInfo] = []
    for _ in 0..<200 {
      statusEvents = delegate.eventInfosReceived.filter {
        if case .subscriptionStatusDidChange = $0.event {
          return true
        }
        return false
      }
      if statusEvents.count >= 2 {
        break
      }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    try #require(statusEvents.count == 2)
    let activeEvent = try #require(
      statusEvents.first { ($0.params["status"] as? String) == SubscriptionStatus.active([grant]).description }
    )
    #expect(activeEvent.params["granted_entitlement_ids"] as? String == "granted")
  }
}
