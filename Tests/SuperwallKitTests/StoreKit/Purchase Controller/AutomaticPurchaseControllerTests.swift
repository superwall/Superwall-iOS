//
//  AutomaticPurchaseControllerTests.swift
//  SuperwallKit
//
//  Created on 15/08/2026.
//

import Testing
@testable import SuperwallKit
import Foundation

/// Tests for the anti-downgrade guard in `AutomaticPurchaseController`.
///
/// These tests reproduce a production failure. A user who pays through
/// Stripe has no App Store purchases. On every cold launch, the automatic
/// StoreKit sync reads zero purchases. Before the guard, that empty read
/// set the status to `.inactive` and persisted it, even though the cached
/// status said `.active`. Recovery needed a network poll, so features
/// gated on entitlements broke on weak internet.
@Suite(.serialized)
struct AutomaticPurchaseControllerTests {
  let dependencyContainer = DependencyContainer()

  init() {
    // Clear state that a previous test may have left on disk.
    dependencyContainer.storage.delete(LatestRedeemResponse.self)
    dependencyContainer.storage.delete(SubscriptionStatusKey.self)
    dependencyContainer.storage.delete(LastWebEntitlementsFetchDate.self)
  }

  /// A web entitlement like the one a Stripe subscriber holds.
  private func stripeEntitlement(expiresAt: Date?) -> Entitlement {
    return Entitlement(
      id: "pro",
      type: .serviceLevel,
      isActive: true,
      productIds: [],
      latestProductId: nil,
      store: .stripe,
      startsAt: Date().addingTimeInterval(-90 * 86_400),
      renewedAt: nil,
      expiresAt: expiresAt,
      isLifetime: false,
      willRenew: true,
      state: nil,
      offerType: nil
    )
  }

  private func makeController() -> AutomaticPurchaseController {
    return AutomaticPurchaseController(
      factory: dependencyContainer,
      entitlementsInfo: dependencyContainer.entitlementsInfo
    )
  }

  // MARK: - The observed production bug

  @Test("Cold launch with empty device read keeps an unexpired active status")
  func testEmptyDeviceRead_keepsUnexpiredActiveStatus() async {
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // A months-long Stripe subscriber. The last session persisted `.active`.
    let entitlement = stripeEntitlement(expiresAt: Date().addingTimeInterval(30 * 86_400))
    dependencyContainer.storage.save(
      SubscriptionStatus.active([entitlement]),
      forType: SubscriptionStatusKey.self
    )

    // The web cache is missing. This happens after a poisoned poll response,
    // a storage reset, or a failed cache migration. Without the guard, the
    // web-entitlement merge cannot rescue the status.
    dependencyContainer.storage.delete(LatestRedeemResponse.self)

    // Cold launch restores the persisted status, as `configure` does.
    await MainActor.run {
      superwall.subscriptionStatus =
        dependencyContainer.storage.get(SubscriptionStatusKey.self) ?? .unknown
    }

    // The automatic StoreKit sync reads zero purchases. This is correct for
    // a Stripe subscriber: they have no App Store transactions.
    let controller = makeController()
    await controller.syncSubscriptionStatus(withPurchases: [], superwall: superwall)

    // Before the fix, the status flipped to `.inactive` here. The user's
    // event stream showed this flip 10 times, 0.8s after cold launch.
    let status = await MainActor.run { superwall.subscriptionStatus }
    if case .active(let entitlements) = status {
      #expect(entitlements.contains(entitlement))
    } else {
      Issue.record("A paying subscriber must not flip to \(status) on an empty device read")
    }
  }

  @Test("Full cold launch on weak internet keeps access for a Stripe subscriber")
  func testStripeSubscriberColdLaunchOnWeakInternet_keepsAccess() async {
    guard #available(iOS 14.0, *) else {
      return
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // Step 1: a previous session persisted `.active` for the Stripe subscriber.
    let entitlement = stripeEntitlement(expiresAt: Date().addingTimeInterval(30 * 86_400))
    dependencyContainer.storage.save(
      SubscriptionStatus.active([entitlement]),
      forType: SubscriptionStatusKey.self
    )
    dependencyContainer.storage.delete(LatestRedeemResponse.self)

    // Step 2: cold launch restores the status from disk.
    await MainActor.run {
      superwall.subscriptionStatus =
        dependencyContainer.storage.get(SubscriptionStatusKey.self) ?? .unknown
    }

    // Step 3: the web entitlement poll fails. The network is unreachable.
    // NetworkMock throws when no response is set.
    let options = dependencyContainer.makeSuperwallOptions()
    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )
    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: dependencyContainer.storage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )
    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
        to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL(string: "https://superwall.com")!)
      )
    await redeemer.pollWebEntitlements(config: config, isFirstTime: true)

    // Step 4: the StoreKit sync reads zero purchases.
    let controller = makeController()
    await controller.syncSubscriptionStatus(withPurchases: [], superwall: superwall)

    // The subscriber keeps access with zero network on the critical path.
    let status = await MainActor.run { superwall.subscriptionStatus }
    if case .active(let entitlements) = status {
      #expect(entitlements.contains(entitlement))
    } else {
      Issue.record("Status was \(status); a weak-internet cold launch must not remove access")
    }
  }

  // MARK: - The guard must not block real deactivation

  @Test("Empty device read deactivates an expired status")
  func testEmptyDeviceRead_expiredStatus_becomesInactive() async {
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // The subscription lapsed a day ago.
    let entitlement = stripeEntitlement(expiresAt: Date().addingTimeInterval(-86_400))
    dependencyContainer.storage.delete(LatestRedeemResponse.self)
    await MainActor.run {
      superwall.subscriptionStatus = .active([entitlement])
    }

    let controller = makeController()
    await controller.syncSubscriptionStatus(withPurchases: [], superwall: superwall)

    let status = await MainActor.run { superwall.subscriptionStatus }
    #expect(status == .inactive, "An expired status must not survive an empty device read")
  }

  @Test("Empty device read deactivates a status with no expiry date")
  func testEmptyDeviceRead_nilExpiry_becomesInactive() async {
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // No expiry date means the guard cannot bound the protection, so it
    // does not apply. A revoked lifetime purchase deactivates this way.
    let entitlement = Entitlement(
      id: "pro",
      type: .serviceLevel,
      isActive: true,
      productIds: ["lifetime_product"],
      latestProductId: "lifetime_product",
      store: .appStore,
      startsAt: Date(),
      renewedAt: nil,
      expiresAt: nil,
      isLifetime: true,
      willRenew: nil,
      state: nil,
      offerType: nil
    )
    dependencyContainer.storage.delete(LatestRedeemResponse.self)
    await MainActor.run {
      superwall.subscriptionStatus = .active([entitlement])
    }

    let controller = makeController()
    await controller.syncSubscriptionStatus(withPurchases: [], superwall: superwall)

    let status = await MainActor.run { superwall.subscriptionStatus }
    #expect(status == .inactive, "A status with no expiry date must not hold the guard")
  }

  @Test("Empty device read from an inactive status stays inactive")
  func testEmptyDeviceRead_inactiveStatus_staysInactive() async {
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    dependencyContainer.storage.delete(LatestRedeemResponse.self)
    await MainActor.run {
      superwall.subscriptionStatus = .inactive
    }

    let controller = makeController()
    await controller.syncSubscriptionStatus(withPurchases: [], superwall: superwall)

    let status = await MainActor.run { superwall.subscriptionStatus }
    #expect(status == .inactive)
  }

  // MARK: - Existing behavior is unchanged

  @Test("Empty device read still rescues via cached web entitlements")
  func testEmptyDeviceRead_withCachedWebEntitlements_staysActiveViaMerge() async {
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // The status starts inactive, so the guard does not apply. The cached
    // web entitlements alone must rescue the user, as before the fix.
    let entitlement = stripeEntitlement(expiresAt: Date().addingTimeInterval(30 * 86_400))
    let redeemResponse = RedeemResponse.stub()
      .setting(
        \.customerInfo,
        to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [entitlement])
      )
    dependencyContainer.storage.save(redeemResponse, forType: LatestRedeemResponse.self)
    await MainActor.run {
      superwall.subscriptionStatus = .inactive
    }

    let controller = makeController()
    await controller.syncSubscriptionStatus(withPurchases: [], superwall: superwall)

    let status = await MainActor.run { superwall.subscriptionStatus }
    if case .active(let entitlements) = status {
      #expect(entitlements.contains(entitlement))
    } else {
      Issue.record("Cached web entitlements must rescue an empty device read")
    }

    dependencyContainer.storage.delete(LatestRedeemResponse.self)
  }

  @Test("Active purchases set an active status")
  func testActivePurchases_setActiveStatus() async {
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    let entitlement = Entitlement(id: "premium")
    dependencyContainer.entitlementsInfo.entitlementsByProductId = [
      "monthly_product": [entitlement]
    ]
    dependencyContainer.storage.delete(LatestRedeemResponse.self)
    await MainActor.run {
      superwall.subscriptionStatus = .unknown
    }

    let controller = makeController()
    let purchase = Purchase(
      id: "monthly_product",
      isActive: true,
      purchaseDate: Date()
    )
    await controller.syncSubscriptionStatus(withPurchases: [purchase], superwall: superwall)

    let status = await MainActor.run { superwall.subscriptionStatus }
    if case .active(let entitlements) = status {
      #expect(entitlements.contains(entitlement))
    } else {
      Issue.record("An active purchase must produce an active status")
    }
  }
}
