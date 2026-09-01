//
//  GrantedEntitlementsTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-01.
//
// swiftlint:disable all

@testable import SuperwallKit
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

    #expect(!superwall.subscriptionStatus.isActive)
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
  func granted_mergesIntoAutomaticPathCustomerInfo() {
    superwall.grantedEntitlements = [grantedEntitlement()]

    let base = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [deviceEntitlement(id: "premium")]
    )
    let merged = base.mergingGrantedEntitlements(from: dependencyContainer.storage)

    #expect(Set(merged.entitlements.map(\.id)) == ["premium", "granted"])
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
