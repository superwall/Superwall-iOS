//
//  SubscriptionStatusLogicalEqualityTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-01.
//
// swiftlint:disable all

@testable import SuperwallKit
import Testing
import Foundation

struct SubscriptionStatusLogicalEqualityTests {
  // MARK: - Helpers

  private func enrichedEntitlement(
    id: String = "premium",
    isActive: Bool = true,
    expiresAt: Date? = Date(timeIntervalSince1970: 1_800_000_000)
  ) -> Entitlement {
    return Entitlement(
      id: id,
      type: .serviceLevel,
      isActive: isActive,
      productIds: ["com.example.monthly", "com.example.annual"],
      latestProductId: "com.example.monthly",
      store: .appStore,
      startsAt: Date(timeIntervalSince1970: 1_700_000_000),
      renewedAt: Date(timeIntervalSince1970: 1_750_000_000),
      expiresAt: expiresAt,
      isLifetime: false,
      willRenew: true,
      state: .subscribed,
      offerType: nil
    )
  }

  // MARK: - Case comparisons

  @Test
  func sameCases_areLogicallyEqual() {
    #expect(SubscriptionStatus.unknown.isLogicallyEqual(to: .unknown))
    #expect(SubscriptionStatus.inactive.isLogicallyEqual(to: .inactive))
  }

  @Test
  func differentCases_areNotLogicallyEqual() {
    #expect(!SubscriptionStatus.unknown.isLogicallyEqual(to: .inactive))
    #expect(!SubscriptionStatus.inactive.isLogicallyEqual(to: .active([Entitlement(id: "premium")])))
    #expect(!SubscriptionStatus.active([Entitlement(id: "premium")]).isLogicallyEqual(to: .unknown))
  }

  // MARK: - Active status comparisons

  @Test
  func active_identicalEntitlements_areLogicallyEqual() {
    let status: SubscriptionStatus = .active([enrichedEntitlement()])
    let repeatWrite: SubscriptionStatus = .active([enrichedEntitlement()])
    #expect(status.isLogicallyEqual(to: repeatWrite))
  }

  @Test
  func active_bareVsEnrichedEntitlement_areLogicallyEqual() {
    // An app using a purchase controller writes a bare entitlement while the
    // SDK holds an enriched one with transaction metadata. Deep equality says
    // these differ; logically the status is unchanged.
    let bare: SubscriptionStatus = .active([Entitlement(id: "premium")])
    let enriched: SubscriptionStatus = .active([enrichedEntitlement()])
    #expect(bare != enriched)
    #expect(bare.isLogicallyEqual(to: enriched))
  }

  @Test
  func active_driftingMetadata_areLogicallyEqual() {
    let first: SubscriptionStatus = .active([
      enrichedEntitlement(expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
    ])
    let second: SubscriptionStatus = .active([
      enrichedEntitlement(expiresAt: Date(timeIntervalSince1970: 1_800_000_000.5))
    ])
    #expect(first != second)
    #expect(first.isLogicallyEqual(to: second))
  }

  @Test
  func active_differentEntitlementIds_areNotLogicallyEqual() {
    let premium: SubscriptionStatus = .active([enrichedEntitlement(id: "premium")])
    let pro: SubscriptionStatus = .active([enrichedEntitlement(id: "pro")])
    #expect(!premium.isLogicallyEqual(to: pro))
  }

  @Test
  func active_addedEntitlement_areNotLogicallyEqual() {
    let one: SubscriptionStatus = .active([enrichedEntitlement(id: "premium")])
    let two: SubscriptionStatus = .active([
      enrichedEntitlement(id: "premium"),
      enrichedEntitlement(id: "pro")
    ])
    #expect(!one.isLogicallyEqual(to: two))
  }

  @Test
  func active_isActiveFlip_areNotLogicallyEqual() {
    let active: SubscriptionStatus = .active([enrichedEntitlement(isActive: true)])
    let lapsed: SubscriptionStatus = .active([enrichedEntitlement(isActive: false)])
    #expect(!active.isLogicallyEqual(to: lapsed))
  }

  // MARK: - Persistence

  @Test
  func setSubscriptionStatus_metadataOnlyUpdate_refreshesCache() {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    dependencyContainer.storage.delete(SubscriptionStatusKey.self)

    let first: SubscriptionStatus = .active([
      enrichedEntitlement(expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
    ])
    superwall.subscriptionStatus = first
    #expect(dependencyContainer.storage.get(SubscriptionStatusKey.self) == first)

    // Same logical state, different metadata. The listener dedupes this,
    // but the persisted cache must still refresh.
    let renewed: SubscriptionStatus = .active([
      enrichedEntitlement(expiresAt: Date(timeIntervalSince1970: 1_900_000_000))
    ])
    superwall.subscriptionStatus = renewed
    #expect(dependencyContainer.storage.get(SubscriptionStatusKey.self) == renewed)
  }

  // MARK: - Listener dedupe

  @Test
  func listener_metadataOnlyUpdate_doesNotCallDelegate() async {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let delegate = MockSuperwallDelegate()
    dependencyContainer.delegateAdapter.swiftDelegate = delegate
    superwall.listenToSubscriptionStatus()

    superwall.subscriptionStatus = .active([Entitlement(id: "premium")])
    await waitUntil { delegate.subscriptionStatusChanges.count == 1 }
    #expect(delegate.subscriptionStatusChanges.count == 1)

    // Metadata-only update: same id/type/isActive, enriched with
    // transaction metadata. Must not call the delegate again.
    superwall.subscriptionStatus = .active([enrichedEntitlement(id: "premium")])
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(delegate.subscriptionStatusChanges.count == 1)

    // A logical change must still call the delegate.
    superwall.subscriptionStatus = .inactive
    await waitUntil { delegate.subscriptionStatusChanges.count == 2 }
    #expect(delegate.subscriptionStatusChanges.count == 2)

    // A different entitlement id is also a logical change.
    superwall.subscriptionStatus = .active([enrichedEntitlement(id: "pro")])
    await waitUntil { delegate.subscriptionStatusChanges.count == 3 }
    #expect(delegate.subscriptionStatusChanges.count == 3)
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
}
