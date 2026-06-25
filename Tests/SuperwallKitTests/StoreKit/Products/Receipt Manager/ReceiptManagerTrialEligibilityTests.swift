//
//  ReceiptManagerTrialEligibilityTests.swift
//  SuperwallKitTests
//
// Regression tests for a bug where a paywall showed a free trial that Apple never
// granted. A customer who had paid for a product in a subscription group since 2017
// (but never taken a trial) is still reported eligible by StoreKit's
// `isEligibleForIntroOffer`. When they bought a *different* product in that group
// while their existing subscription was active, Apple treated it as an upgrade and
// applied no introductory offer — yet the paywall advertised one.
//
// `ReceiptManager.isFreeTrialAvailable` now additionally requires that there's no
// active App Store subscription in the product's subscription group, since Apple
// doesn't apply intro offers to upgrades/crossgrades/downgrades.
//

import Foundation
import StoreKit
import Testing
@testable import SuperwallKit

struct ReceiptManagerTrialEligibilityTests {
  // Held for the lifetime of each test: `ReceiptManager` keeps an `unowned` reference
  // to its factory, so the container must outlive the manager.
  let dependencyContainer = DependencyContainer()

  private func makeReceiptManager(
    isEligibleForIntroOffer: Bool,
    deviceSubscriptions: [SubscriptionTransaction]
  ) -> (manager: ReceiptManager, productsManager: ProductsManager) {
    let storage: Storage = dependencyContainer.storage
    storage.save(
      CustomerInfo(
        subscriptions: deviceSubscriptions,
        nonSubscriptions: [],
        entitlements: []
      ),
      forType: LatestDeviceCustomerInfo.self
    )

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
      storage: storage
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

  private func activeSubscription(
    productId: String,
    group: String?,
    isActive: Bool = true,
    store: ProductStore = .appStore
  ) -> SubscriptionTransaction {
    return SubscriptionTransaction(
      transactionId: "txn_\(productId)",
      productId: productId,
      purchaseDate: Date(timeIntervalSince1970: 0),
      willRenew: isActive,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: isActive,
      expirationDate: nil,
      offerType: nil,
      subscriptionGroupId: group,
      store: store
    )
  }

  @Test("No trial when an active subscription exists in the same group (upgrade/crossgrade)")
  func noTrialWhenActiveSubscriptionInSameGroup() async {
    // The reported incident: active Silver in group_A, buying Gold in group_A.
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      deviceSubscriptions: [activeSubscription(productId: "com.app.silver", group: "group_A")]
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == false)
  }

  @Test("Trial available once the same-group subscription has lapsed")
  func trialWhenSameGroupSubscriptionInactive() async {
    // After Silver lapsed, a fresh purchase in the group is a new subscription, so
    // Apple applies the trial again.
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      deviceSubscriptions: [
        activeSubscription(productId: "com.app.silver", group: "group_A", isActive: false)
      ]
    )
    _ = productsManager
    let silver = makeProduct(id: "com.app.silver", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: silver) == true)
  }

  @Test("Trial available when the active subscription is in a different group")
  func trialWhenActiveSubscriptionInDifferentGroup() async {
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      deviceSubscriptions: [activeSubscription(productId: "com.app.other", group: "group_B")]
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == true)
  }

  @Test("Trial available when there are no subscriptions at all")
  func trialWhenNoSubscriptions() async {
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      deviceSubscriptions: []
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == true)
  }

  @Test("No trial when StoreKit reports the customer is intro-ineligible")
  func noTrialWhenIneligible() async {
    // Even with no blocking subscription, an ineligible customer gets no trial.
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: false,
      deviceSubscriptions: []
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == false)
  }

  @Test("A non-App Store subscription in the group does not block the trial")
  func nonAppStoreSubscriptionDoesNotBlock() async {
    // The upgrade rule is an App Store concept; a web/Stripe entitlement in the same
    // group must not suppress an App Store trial.
    let (manager, productsManager) = makeReceiptManager(
      isEligibleForIntroOffer: true,
      deviceSubscriptions: [
        activeSubscription(productId: "com.app.silver", group: "group_A", store: .stripe)
      ]
    )
    _ = productsManager
    let gold = makeProduct(id: "com.app.gold", subscriptionGroup: "group_A")
    #expect(await manager.isFreeTrialAvailable(for: gold) == true)
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
