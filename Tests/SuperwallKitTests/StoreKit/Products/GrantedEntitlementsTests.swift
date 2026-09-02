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
    dependencyContainer = DependencyContainer()
    superwall = Superwall(dependencyContainer: dependencyContainer)
    cleanStorage()
  }

  deinit {
    cleanStorage()
  }

  private func cleanStorage() {
    dependencyContainer.storage.delete(GrantedEntitlements.self)
    dependencyContainer.storage.delete(SubscriptionStatusKey.self)
    dependencyContainer.storage.delete(LatestRedeemResponse.self)
    dependencyContainer.storage.delete(LatestDeviceCustomerInfo.self)
  }

  // MARK: - Helpers

  /// A bare developer-granted entitlement: no transaction history, no store.
  private func grantedEntitlement(
    id: String = "granted",
    isActive: Bool = true
  ) -> Entitlement {
    return Entitlement(
      id: id,
      type: .serviceLevel,
      isActive: isActive
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

  // MARK: - Merging

  @Test
  func settingGranted_activatesInactiveStatus() {
    superwall.subscriptionStatus = .inactive
    superwall.grantedEntitlements = [grantedEntitlement()]

    #expect(superwall.subscriptionStatus.isActive)
    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.map(\.id) == ["granted"])
    } else {
      Issue.record("Expected .active status")
    }
  }

  @Test
  func settingGranted_mergesWithActiveStatus() {
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])
    superwall.grantedEntitlements = [grantedEntitlement(id: "granted")]

    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(Set(entitlements.map(\.id)) == ["premium", "granted"])
    } else {
      Issue.record("Expected .active status")
    }
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

    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.map(\.id) == ["premium"])
    } else {
      Issue.record("Expected .active status")
    }
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

    #expect(superwall.subscriptionStatus.isActive)
    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.map(\.id) == ["granted"])
    }
  }

  @Test
  func emptyActiveAssignment_stillMergesGranted() {
    // The empty-.active → .inactive collapse must run after the granted
    // merge, not before it.
    superwall.grantedEntitlements = [grantedEntitlement()]
    superwall.subscriptionStatus = .active([])

    #expect(superwall.subscriptionStatus.isActive)
  }

  // MARK: - Clearing

  @Test
  func clearingGranted_restoresBaseStatus() {
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

    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.map(\.id) == ["b"])
    } else {
      Issue.record("Expected .active status")
    }
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
  func reassigningResolvedStatus_isStable() {
    superwall.subscriptionStatus = .active([deviceEntitlement(id: "premium")])
    superwall.grantedEntitlements = [grantedEntitlement(id: "granted")]

    let resolved = superwall.subscriptionStatus
    superwall.subscriptionStatus = resolved

    // resolve(resolve(x)) == resolve(x): re-resolving an already-merged
    // value must settle, not loop or grow.
    #expect(superwall.subscriptionStatus == resolved)
  }

  // MARK: - Persistence

  @Test
  func persistedStatus_isUnresolvedBase() {
    superwall.grantedEntitlements = [grantedEntitlement()]
    superwall.subscriptionStatus = .inactive

    // The published status is merged, but the persisted one must be the
    // unresolved base — otherwise granted entitlements are baked into the
    // restored value and can never be cleared after a relaunch.
    #expect(superwall.subscriptionStatus.isActive)
    #expect(dependencyContainer.storage.get(SubscriptionStatusKey.self) == .inactive)
  }

  @Test
  func clearingGranted_afterRestore_restoresBaseStatus() {
    superwall.grantedEntitlements = [grantedEntitlement()]
    superwall.subscriptionStatus = .inactive
    #expect(superwall.subscriptionStatus.isActive)

    // Simulate a relaunch: a fresh instance restores the persisted status,
    // exactly as Superwall's configure init does.
    let relaunched = Superwall(dependencyContainer: dependencyContainer)
    relaunched.subscriptionStatus =
      dependencyContainer.storage.get(SubscriptionStatusKey.self) ?? .unknown
    #expect(relaunched.subscriptionStatus.isActive)

    relaunched.grantedEntitlements = []

    #expect(relaunched.subscriptionStatus == .inactive)
  }

  @Test
  func concurrentAssignments_neverPersistGrantedIntoBase() async {
    superwall.grantedEntitlements = [grantedEntitlement()]

    // Race external assignments from many threads. Without the lock
    // covering the property store, a store landing mid-resolution captures
    // another thread's resolved write-back as its base, persisting granted
    // entitlements into SubscriptionStatusKey.
    await withTaskGroup(of: Void.self) { group in
      for index in 0..<50 {
        group.addTask { [superwall, deviceEnt = deviceEntitlement(id: "premium")] in
          superwall.subscriptionStatus = index.isMultiple(of: 2)
            ? .inactive
            : .active([deviceEnt])
        }
      }
    }

    // The persisted base must be exactly one of the assigned values —
    // any merged base means a resolved write-back was captured.
    let persistedBase = dependencyContainer.storage.get(SubscriptionStatusKey.self)
    #expect(
      persistedBase == .inactive
        || persistedBase == .active([deviceEntitlement(id: "premium")])
    )
    // The in-memory base must be clean too: clearing the grant must leave
    // a status without it.
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
      subscriptionStatus: .inactive
    )

    #expect(customerInfo.entitlements.contains { $0.id == "granted" && $0.isActive })
  }

  @Test
  func grantChange_refreshesCustomerInfoOnAutomaticPath() {
    superwall.grantedEntitlements = [grantedEntitlement()]
    #expect(superwall.customerInfo.entitlements.contains { $0.id == "granted" && $0.isActive })

    superwall.grantedEntitlements = []
    #expect(!superwall.customerInfo.entitlements.contains { $0.id == "granted" })
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
  }

  // MARK: - Publishing

  @Test
  func baseAssignment_publishesOnlyTheResolvedValue() {
    superwall.grantedEntitlements = [grantedEntitlement()]

    var published: [SubscriptionStatus] = []
    let cancellable = superwall.$subscriptionStatus
      .dropFirst()
      .sink { published.append($0) }
    defer { cancellable.cancel() }

    superwall.setSubscriptionStatus(base: .active([deviceEntitlement(id: "premium")]))

    // A single store of the merged value — never the raw base first.
    #expect(published.count == 1)
    if case .active(let entitlements) = published.first {
      #expect(Set(entitlements.map(\.id)) == ["premium", "granted"])
    } else {
      Issue.record("Expected .active status")
    }
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
    // assignment, both resolve back to the granted status. The delegate
    // must not hear about either — in particular it must never see the
    // transient .inactive that the public setter stores before resolution.
    superwall.setSubscriptionStatus(base: .inactive)
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
