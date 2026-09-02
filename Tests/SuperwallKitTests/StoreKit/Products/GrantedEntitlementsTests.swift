//
//  GrantedEntitlementsTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-01.
//
// swiftlint:disable all

@testable import SuperwallKit
import Combine
import Testing
import Foundation

@Suite(.serialized)
final class GrantedEntitlementsTests {
  private let dependencyContainer: DependencyContainer
  private let superwall: Superwall

  init() {
    // In-memory storage, so nothing this suite writes reaches the on-disk
    // store shared with other suites. GrantedEntitlements is app-specific
    // and read on every status publish, so a file left behind mid-test would
    // leak into suites running in parallel.
    dependencyContainer = DependencyContainer(cache: CacheMock())
    superwall = Superwall(dependencyContainer: dependencyContainer)
  }

  // MARK: - Helpers

  /// A bare developer-granted entitlement: no transaction history, no store.
  private func grantedEntitlement(
    id: String = "granted",
    isActive: Bool = true,
    expiresAt: Date? = nil
  ) -> Entitlement {
    return Entitlement(
      id: id,
      type: .serviceLevel,
      isActive: isActive,
      expiresAt: expiresAt
    )
  }

  /// A device entitlement enriched with transaction metadata.
  private func deviceEntitlement(
    id: String = "premium",
    isActive: Bool = true
  ) -> Entitlement {
    return Entitlement(
      id: id,
      type: .serviceLevel,
      isActive: isActive,
      productIds: ["com.example.monthly"],
      latestProductId: "com.example.monthly",
      store: .appStore,
      startsAt: Date(timeIntervalSince1970: 1_700_000_000),
      expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
      isLifetime: false,
      willRenew: true,
      state: .subscribed
    )
  }

  private func activeIds(_ status: SubscriptionStatus) -> Set<String>? {
    if case .active(let entitlements) = status {
      return Set(entitlements.map(\.id))
    }
    return nil
  }

  // MARK: - Merging

  @Test
  func settingGranted_activatesInactiveStatus() {
    superwall.subscriptionStatus = .inactive
    superwall.grantedEntitlements = [grantedEntitlement()]

    #expect(superwall.subscriptionStatus.isActive)
    #expect(activeIds(superwall.subscriptionStatus) == ["granted"])
  }

  @Test
  func settingGranted_mergesWithActiveStatus() {
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])
    superwall.grantedEntitlements = [grantedEntitlement(id: "granted")]

    #expect(activeIds(superwall.subscriptionStatus) == ["premium", "granted"])
  }

  @Test
  func unknownStatus_promotesToActiveWithGranted() {
    superwall.subscriptionStatus = .unknown
    superwall.grantedEntitlements = [grantedEntitlement()]

    #expect(superwall.subscriptionStatus.isActive)
  }

  @Test
  func inactiveGrantedOnly_doesNotActivateStatus() {
    superwall.subscriptionStatus = .inactive
    superwall.grantedEntitlements = [grantedEntitlement(isActive: false)]

    // Inactive-only grants must not promote — the status stays .inactive,
    // not an .active-cased status that's effectively inactive.
    #expect(superwall.subscriptionStatus == .inactive)
  }

  @Test
  func inactiveGrant_doesNotEnterActiveSet() {
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])
    superwall.grantedEntitlements = [grantedEntitlement(id: "extra", isActive: false)]

    #expect(activeIds(superwall.subscriptionStatus) == ["premium"])
  }

  @Test
  func inactiveGrantedOnly_leavesUnknownStatusUnknown() {
    superwall.subscriptionStatus = .unknown
    superwall.grantedEntitlements = [grantedEntitlement(isActive: false)]

    #expect(superwall.subscriptionStatus == .unknown)
  }

  @Test
  func assigningInactive_keepsGrantedActive() {
    superwall.grantedEntitlements = [grantedEntitlement()]
    superwall.subscriptionStatus = .active([deviceEntitlement()])

    superwall.subscriptionStatus = .inactive

    #expect(activeIds(superwall.subscriptionStatus) == ["granted"])
  }

  @Test
  func emptyActiveAssignment_stillMergesGranted() {
    // The empty-.active → .inactive collapse must run after the granted
    // merge, not before it.
    superwall.grantedEntitlements = [grantedEntitlement()]
    superwall.subscriptionStatus = .active([])

    #expect(superwall.subscriptionStatus.isActive)
  }

  @Test
  func grantsSharingAnId_publishOneRecord() {
    superwall.subscriptionStatus = .inactive
    superwall.grantedEntitlements = [
      grantedEntitlement(id: "pro", expiresAt: Date(timeIntervalSince1970: 1_800_000_000)),
      grantedEntitlement(id: "pro", expiresAt: Date(timeIntervalSince1970: 1_900_000_000))
    ]

    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.count == 1)
      // The later expiry wins the merge.
      #expect(entitlements.first?.expiresAt == Date(timeIntervalSince1970: 1_900_000_000))
    } else {
      Issue.record("Expected .active status")
    }
  }

  // MARK: - Clearing

  @Test
  func clearingGranted_restoresAssignedStatus() {
    superwall.subscriptionStatus = .inactive
    superwall.grantedEntitlements = [grantedEntitlement()]
    #expect(superwall.subscriptionStatus.isActive)

    superwall.grantedEntitlements = []

    #expect(superwall.subscriptionStatus == .inactive)
  }

  @Test
  func replacingGranted_replacesOutright() {
    superwall.subscriptionStatus = .inactive
    superwall.grantedEntitlements = [grantedEntitlement(id: "a")]
    superwall.grantedEntitlements = [grantedEntitlement(id: "b")]

    #expect(activeIds(superwall.subscriptionStatus) == ["b"])
  }

  @Test
  func writingBackThePublishedStatus_keepsGrantsRevocable() {
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])
    superwall.grantedEntitlements = [grantedEntitlement()]

    // A read-modify-write of the published, grant-merged status must not
    // hand the grant back as the developer's own.
    superwall.subscriptionStatus = superwall.subscriptionStatus
    #expect(
      dependencyContainer.storage.get(SubscriptionStatusKey.self)
        == .active([deviceEntitlement(id: "premium")])
    )

    superwall.grantedEntitlements = []

    #expect(activeIds(superwall.subscriptionStatus) == ["premium"])
  }

  @Test
  func writingBackACollidingGrant_keepsItRevocable() {
    // A lapsed subscription and a grant for the same ID: the grant wins the
    // merge but comes back carrying the lapsed record's product IDs, so it
    // no longer equals the grant it came from.
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium", isActive: false)])
    superwall.grantedEntitlements = [grantedEntitlement(id: "premium")]

    superwall.subscriptionStatus = superwall.subscriptionStatus
    superwall.grantedEntitlements = []

    #expect(!superwall.subscriptionStatus.isActive)
  }

  // MARK: - Merge precedence

  @Test
  func granted_losesToActiveDeviceEntitlementWithHistory() {
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])
    superwall.grantedEntitlements = [grantedEntitlement(id: "premium")]

    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.count == 1)
      // The device entitlement's transaction metadata must be kept.
      #expect(entitlements.first?.latestProductId == "com.example.monthly")
      #expect(entitlements.first?.store == .appStore)
    } else {
      Issue.record("Expected .active status")
    }
  }

  @Test
  func activeGranted_beatsExpiredDeviceEntitlement() {
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium", isActive: false)])
    superwall.grantedEntitlements = [grantedEntitlement(id: "premium")]

    #expect(superwall.subscriptionStatus.isActive)
    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.count == 1)
      #expect(entitlements.first?.isActive == true)
      // The granted record wins wholesale — it mustn't inherit the expired
      // transaction's metadata and masquerade as a store subscription.
      #expect(entitlements.first?.latestProductId == nil)
    } else {
      Issue.record("Expected .active status")
    }
  }

  // MARK: - Idempotence

  @Test
  func reassigningPublishedStatus_isStable() {
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])
    superwall.grantedEntitlements = [grantedEntitlement(id: "granted")]

    let published = superwall.subscriptionStatus
    superwall.subscriptionStatus = published

    // merge(merge(x)) == merge(x): re-assigning an already-merged value
    // must settle, not loop or grow.
    #expect(superwall.subscriptionStatus == published)
  }

  // MARK: - Persistence

  @Test
  func persistedStatus_isAssignedValue() {
    superwall.grantedEntitlements = [grantedEntitlement()]
    superwall.subscriptionStatus = .inactive

    // The published status is merged, but the persisted one must be the
    // assigned value — otherwise granted entitlements are baked into the
    // restored value and can never be cleared after a relaunch.
    #expect(superwall.subscriptionStatus.isActive)
    #expect(dependencyContainer.storage.get(SubscriptionStatusKey.self) == .inactive)
  }

  @Test
  func clearingGranted_afterRestore_restoresAssignedStatus() {
    superwall.grantedEntitlements = [grantedEntitlement()]
    superwall.subscriptionStatus = .inactive
    #expect(superwall.subscriptionStatus.isActive)

    // Simulate a relaunch: a fresh instance restores the persisted status,
    // exactly as Superwall's configure init does.
    let relaunched = Superwall(dependencyContainer: dependencyContainer)
    relaunched.setSubscriptionStatus(
      assigned: dependencyContainer.storage.get(SubscriptionStatusKey.self) ?? .unknown
    )
    #expect(relaunched.subscriptionStatus.isActive)

    relaunched.grantedEntitlements = []

    #expect(relaunched.subscriptionStatus == .inactive)
  }

  @Test
  func concurrentAssignments_neverPersistGrantedIntoAssignedStatus() async {
    superwall.grantedEntitlements = [grantedEntitlement()]

    // Race external assignments from many threads. Without the lock, a store
    // landing mid-publish could capture another thread's merged write-back
    // as its assigned status, persisting granted entitlements into
    // SubscriptionStatusKey.
    await withTaskGroup(of: Void.self) { group in
      for index in 0..<50 {
        group.addTask { [superwall, deviceEnt = deviceEntitlement(id: "premium")] in
          superwall.subscriptionStatus = index.isMultiple(of: 2)
            ? .inactive
            : .active([deviceEnt])
        }
      }
    }

    // The persisted status must be exactly one of the assigned values —
    // any merged value means a write-back was captured as the assigned status.
    let persistedStatus = dependencyContainer.storage.get(SubscriptionStatusKey.self)
    #expect(
      persistedStatus == .inactive
        || persistedStatus == .active([deviceEntitlement(id: "premium")])
    )
    // The in-memory assigned status must be clean too: clearing the grant
    // must leave a status without it.
    superwall.grantedEntitlements = []
    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.map(\.id) == ["premium"])
    }
  }

  @Test
  func granted_survivesStorageReset() {
    superwall.grantedEntitlements = [grantedEntitlement()]

    dependencyContainer.storage.reset()

    #expect(superwall.grantedEntitlements.map(\.id) == ["granted"])
  }

  // MARK: - CustomerInfo

  @Test
  func granted_reachesCustomerInfoForExternalPurchaseController() {
    superwall.grantedEntitlements = [grantedEntitlement()]

    let customerInfo = CustomerInfo.forExternalPurchaseController(
      storage: dependencyContainer.storage,
      subscriptionStatus: .inactive,
      granted: superwall.grantedEntitlements
    )

    #expect(customerInfo.entitlements.contains { $0.id == "granted" && $0.isActive })
  }

  @Test
  func preservingExternalControllerEntitlements_keepsGrantCollidingWithExpiredDevice() {
    let expiredDevice = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [deviceEntitlement(id: "premium", isActive: false)]
    )
    // The controller's current customer info also carries "premium", so
    // the externalOnly filter drops it — the grant must survive as its own
    // source rather than ride in through that filter.
    let current = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [deviceEntitlement(id: "premium", isActive: false)]
    )

    let merged = CustomerInfo.preservingExternalControllerEntitlements(
      device: expiredDevice,
      web: nil,
      current: current,
      granted: [grantedEntitlement(id: "premium")]
    )

    #expect(merged.entitlements.count == 1)
    #expect(merged.entitlements.first?.isActive == true)
    #expect(merged.entitlements.first?.latestProductId == nil)
  }

  @Test
  func grantChange_refreshesCustomerInfoOnAutomaticPath() {
    superwall.grantedEntitlements = [grantedEntitlement()]
    #expect(superwall.customerInfo.entitlements.contains { $0.id == "granted" && $0.isActive })

    superwall.grantedEntitlements = []
    #expect(!superwall.customerInfo.entitlements.contains { $0.id == "granted" })
  }

  @Test
  func grantsBeforeTheDeviceSnapshot_keepCustomerInfoAsPlaceholder() {
    #expect(superwall.customerInfo.isPlaceholder)

    superwall.grantedEntitlements = [grantedEntitlement()]

    // Grants alone don't mean the device has been read, so consumers that
    // wait for real data keep waiting.
    #expect(superwall.customerInfo.isPlaceholder)
    #expect(superwall.customerInfo.entitlements.map(\.id) == ["granted"])
  }

  @Test
  func merging_treatsGrantedAsASource() {
    let device = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [deviceEntitlement(id: "premium")]
    )

    let merged = device.merging(with: .blank(), granting: [grantedEntitlement()])

    #expect(merged.entitlements.map(\.id) == ["granted", "premium"])
    #expect(!merged.isPlaceholder)
  }

  // MARK: - Publishing

  @Test
  func sdkAssignment_publishesOnlyTheMergedValue() {
    superwall.grantedEntitlements = [grantedEntitlement()]

    var published: [SubscriptionStatus] = []
    let cancellable = superwall.$subscriptionStatus
      .dropFirst()
      .sink { published.append($0) }
    defer { cancellable.cancel() }

    superwall.setSubscriptionStatus(assigned: .active([deviceEntitlement(id: "premium")]))

    #expect(published.count == 1)
    #expect(published.first.flatMap(activeIds) == ["premium", "granted"])
  }

  @Test
  func developerAssignment_publishesOnlyTheMergedValue() {
    superwall.grantedEntitlements = [grantedEntitlement()]

    var published: [SubscriptionStatus] = []
    let cancellable = superwall.$subscriptionStatus
      .dropFirst()
      .sink { published.append($0) }
    defer { cancellable.cancel() }

    // The public setter must never publish the raw assigned value first.
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])

    #expect(published.count == 1)
    #expect(published.first.flatMap(activeIds) == ["premium", "granted"])
  }

  @Test
  func assignmentFromASubscriber_isApplied() {
    var didReassign = false
    let cancellable = superwall.$subscriptionStatus
      .dropFirst()
      .sink { [superwall] status in
        // A subscriber that reacts to the first change by assigning again,
        // synchronously, from inside the emission.
        if !didReassign, case .active = status {
          didReassign = true
          superwall.subscriptionStatus = .inactive
        }
      }
    defer { cancellable.cancel() }

    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])

    #expect(superwall.subscriptionStatus == .inactive)
    #expect(dependencyContainer.storage.get(SubscriptionStatusKey.self) == .inactive)
  }

  @Test
  func inactiveWritesWithGrant_doNotNotifyDelegate() async {
    let delegate = MockSuperwallDelegate()
    dependencyContainer.delegateAdapter.swiftDelegate = delegate
    superwall.listenToSubscriptionStatus()

    superwall.grantedEntitlements = [grantedEntitlement()]
    await waitUntil { delegate.subscriptionStatusChanges.count == 1 }
    #expect(delegate.subscriptionStatusChanges.count == 1)

    // A device poll reporting no subscription, and a direct .inactive
    // assignment, both publish the granted status again. The delegate
    // must not hear about either.
    superwall.setSubscriptionStatus(assigned: .inactive)
    superwall.subscriptionStatus = .inactive
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(delegate.subscriptionStatusChanges.count == 1)
  }

  private func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: @escaping () -> Bool
  ) async {
    let start = Date()
    while !condition() && Date().timeIntervalSince(start) < timeout {
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
  }

  // MARK: - Event parameters

  @Test
  func statusChangeEvent_includesGrantedEntitlementIds() async {
    let granted = grantedEntitlement(id: "granted")
    let event = InternalSuperwallEvent.SubscriptionStatusDidChange(
      status: .active([deviceEntitlement(id: "premium"), granted]),
      grantedEntitlements: [granted]
    )

    let params = await event.getSuperwallParameters()

    #expect(params["granted_entitlement_ids"] as? String == "granted")
  }

  @Test
  func statusChangeEvent_omitsGrantedParamWhenNoneGranted() async {
    let event = InternalSuperwallEvent.SubscriptionStatusDidChange(
      status: .active([deviceEntitlement(id: "premium")])
    )

    let params = await event.getSuperwallParameters()

    #expect(params["granted_entitlement_ids"] == nil)
  }
}
