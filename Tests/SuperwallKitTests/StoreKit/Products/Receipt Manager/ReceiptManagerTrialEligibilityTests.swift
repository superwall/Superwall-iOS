//
//  ReceiptManagerTrialEligibilityTests.swift
//  SuperwallKitTests
//
// Regression tests for a bug where a paywall showed a free trial that Apple never
// granted. A customer who had paid for a product in a subscription group since 2017
// (but never taken a trial) is still reported eligible by StoreKit's
// `isEligibleForIntroOffer`. When they bought a *different* product in that group while
// their existing subscription was active, Apple treated it as an upgrade and applied no
// introductory offer — yet the paywall advertised one.
//
// `ReceiptManager.isFreeTrialAvailable` now also requires that there's no active
// subscription in the product's subscription group. The set of active groups is computed
// in `loadPurchasedProducts` from the active purchases and their fetched products (so it
// works for both StoreKit 1 and 2); these tests seed it directly to isolate the gate.
//

import Foundation
import Testing
@testable import SuperwallKit

struct ReceiptManagerTrialEligibilityTests {
  // Held for the lifetime of each test: `ReceiptManager` keeps an `unowned` reference
  // to its factory, so the container must outlive the manager.
  let dependencyContainer = DependencyContainer()

  private func makeReceiptManager(
    isEligibleForIntroOffer: Bool,
    activeSubscriptionGroupIds: Set<String>
  ) -> (manager: ReceiptManager, productsManager: ProductsManager) {
    let productsFetcher = ProductsFetcherSK1Mock(
      productCompletionResult: .success([]),
      entitlementsInfo: dependencyContainer.entitlementsInfo
    )
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: productsFetcher
    )

    let receiptManager = ReceiptManager(
      storeKitVersion: .storeKit2,
      shouldBypassAppTransactionCheck: true,
      productsManager: productsManager,
      receiptManager: MockReceiptManagerType(isEligibleForIntroOffer: isEligibleForIntroOffer),
      receiptDelegate: nil,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      activeSubscriptionGroupIds: activeSubscriptionGroupIds
    )
    return (receiptManager, productsManager)
  }

  private func makeProduct(
    id: String = "com.app.gold",
    subscriptionGroup: String? = "group_A"
  ) -> StoreProduct {
    return StoreProduct(
      sk1Product: MockSkProduct(
        productIdentifier: id,
        subscriptionGroupIdentifier: subscriptionGroup
      )
    )
  }

  @Test("No trial when an active subscription exists in the same group (upgrade/crossgrade)")
  func noTrialWhenActiveSubscriptionInSameGroup() async {
    // The reported incident: active Silver in group_A, buying Gold in group_A.
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      activeSubscriptionGroupIds: ["group_A"]
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == false)
  }

  @Test("Trial available once the same-group subscription has lapsed")
  func trialWhenSameGroupSubscriptionInactive() async {
    // After Silver lapsed it's no longer in the active set, so a fresh purchase in the
    // group is a new subscription and Apple applies the trial again.
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      activeSubscriptionGroupIds: []
    )
    _ = productsManager
    let silver = makeProduct(id: "com.app.silver", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: silver) == true)
  }

  @Test("Trial available when the active subscription is in a different group")
  func trialWhenActiveSubscriptionInDifferentGroup() async {
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      activeSubscriptionGroupIds: ["group_B"]
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == true)
  }

  @Test("Trial available when there are no active subscriptions")
  func trialWhenNoActiveSubscriptions() async {
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      activeSubscriptionGroupIds: []
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == true)
  }

  @Test("No trial when StoreKit reports the customer is intro-ineligible")
  func noTrialWhenIneligible() async {
    // Ineligible short-circuits before the active-subscription check.
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: false,
      activeSubscriptionGroupIds: ["group_A"]
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == false)
  }

  @Test("A product with no subscription group is unaffected by the active-group check")
  func trialWhenProductHasNoSubscriptionGroup() async {
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      activeSubscriptionGroupIds: ["group_A"]
    )
    _ = productsManager
    let product = makeProduct(id: "com.app.lifetime", subscriptionGroup: nil)
    #expect(await manager.isFreeTrialAvailable(for: product) == true)
  }
}

/// Minimal `ReceiptManagerType` whose `isEligibleForIntroOffer` is fully controlled,
/// so tests can isolate `ReceiptManager`'s upgrade/crossgrade gating logic.
private final class MockReceiptManagerType: ReceiptManagerType {
  let isEligibleForIntroOfferResult: Bool
  var purchases: Set<Purchase> = []
  var transactionReceipts: [TransactionReceipt] = []
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType?
  var latestSubscriptionWillAutoRenew: Bool?
  var latestSubscriptionState: LatestSubscription.State?

  init(isEligibleForIntroOffer: Bool) {
    self.isEligibleForIntroOfferResult = isEligibleForIntroOffer
  }

  func loadIntroOfferEligibility(forProducts _: Set<StoreProduct>) async {}

  func loadPurchases(serverEntitlementsByProductId _: [String: Set<Entitlement>]) async -> PurchaseSnapshot {
    return PurchaseSnapshot(
      purchases: [],
      customerInfo: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    )
  }

  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool {
    return isEligibleForIntroOfferResult
  }
}
