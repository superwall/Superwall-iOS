//
//  ReceiptManagerPurchasedProductFetchTests.swift
//  SuperwallKitTests
//
// `loadPurchasedProducts` runs before `configState` is published, so every
// `register` call at cold launch waits on it. StoreKit 2 transactions carry
// their subscription group ID, so the active groups come from the snapshot and
// the purchased-product fetch (a network round trip) is skipped. StoreKit 1
// receipts don't carry the group ID, so SK1 still fetches.
//

import Foundation
import Testing
@testable import SuperwallKit

struct ReceiptManagerPurchasedProductFetchTests {
  // Held for the lifetime of each test: `ReceiptManager` keeps an `unowned`
  // reference to its factory, so the container must outlive the manager.
  let dependencyContainer = DependencyContainer()

  private func makeReceiptManager(
    loadsSubscriptionGroupsFromProducts: Bool
  ) -> (manager: ReceiptManager, fetcher: CountingProductsFetcher, productsManager: ProductsManager) {
    let fetcher = CountingProductsFetcher(entitlementsInfo: dependencyContainer.entitlementsInfo)
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: fetcher
    )
    let receiptManager = ReceiptManager(
      storeKitVersion: .storeKit2,
      shouldBypassAppTransactionCheck: true,
      productsManager: productsManager,
      receiptManager: SnapshotReceiptManagerType(
        loadsSubscriptionGroupsFromProducts: loadsSubscriptionGroupsFromProducts
      ),
      receiptDelegate: nil,
      factory: dependencyContainer,
      storage: dependencyContainer.storage
    )
    return (receiptManager, fetcher, productsManager)
  }

  @Test("StoreKit 2 skips the purchased-product fetch and reads groups from the transactions")
  func storeKit2SkipsProductFetch() async {
    let (manager, fetcher, productsManager) = makeReceiptManager(loadsSubscriptionGroupsFromProducts: false)
    _ = productsManager

    await manager.loadPurchasedProducts(config: .stub())

    #expect(fetcher.fetchCount == 0)
    // The active group still gates the trial, so it was read off the transaction.
    let gold = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: "com.app.gold", subscriptionGroupIdentifier: "group_A")
    )
    #expect(await manager.isFreeTrialAvailable(for: gold) == false)
  }

  @Test("StoreKit 1 still fetches the purchased products")
  func storeKit1FetchesProducts() async {
    let (manager, fetcher, productsManager) = makeReceiptManager(loadsSubscriptionGroupsFromProducts: true)
    _ = productsManager

    await manager.loadPurchasedProducts(config: .stub())

    #expect(fetcher.fetchCount == 1)
  }
}

/// Counts product fetches instead of hitting StoreKit.
private final class CountingProductsFetcher: ProductsFetcherSK1 {
  private(set) var fetchCount = 0

  override func products(
    identifiers: Set<String>,
    forPaywall paywall: Paywall?,
    placement: PlacementData?
  ) async throws -> Set<StoreProduct> {
    fetchCount += 1
    return []
  }
}

/// Returns one active subscription in `group_A`, the way an SK2 snapshot would.
private final class SnapshotReceiptManagerType: ReceiptManagerType {
  let loadsSubscriptionGroupsFromProducts: Bool
  var purchases: Set<Purchase> = []
  var transactionReceipts: [TransactionReceipt] = []
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType?
  var latestSubscriptionWillAutoRenew: Bool?
  var latestSubscriptionState: LatestSubscription.State?

  init(loadsSubscriptionGroupsFromProducts: Bool) {
    self.loadsSubscriptionGroupsFromProducts = loadsSubscriptionGroupsFromProducts
  }

  func loadIntroOfferEligibility(forProducts _: Set<StoreProduct>) async {}

  func loadPurchases(serverEntitlementsByProductId _: [String: Set<Entitlement>]) async -> PurchaseSnapshot {
    let silver = SubscriptionTransaction(
      transactionId: "1",
      productId: "com.app.silver",
      purchaseDate: Date(),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: Date().addingTimeInterval(3600),
      subscriptionGroupId: "group_A"
    )
    purchases = [Purchase(id: "com.app.silver", isActive: true, purchaseDate: Date())]
    return PurchaseSnapshot(
      purchases: purchases,
      customerInfo: CustomerInfo(subscriptions: [silver], nonSubscriptions: [], entitlements: [])
    )
  }

  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool {
    return true
  }
}
