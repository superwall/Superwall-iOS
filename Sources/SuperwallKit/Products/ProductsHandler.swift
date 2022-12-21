//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/12/2022.
//

import Foundation

protocol TransactionChecker: AnyObject {
  /// Gets and validates a transaction of a product.
  func getAndValidateTransaction(
    of productId: String,
    since purchaseStartDate: Date
  ) async throws -> StoreTransaction
}

protocol ProductPurchaser: AnyObject {
  /// Purchases a product and returns its result.
  func purchase(product: StoreProduct) async -> PurchaseResult
}

protocol ProductsFetcher: AnyObject {
  /// Fetches a set of products from their identifiers.
  func products(identifiers: Set<String>) async throws -> Set<StoreProduct>
}

protocol TransactionRestorer: AnyObject {
  /// Restores purchases.
  ///
  /// - Returns: A boolean indicating whether the restore request succeeded or failed.
  /// This doesn't mean that the user is now subscribed, just that there were no errors
  /// obtaining the restored transactions
  func restorePurchases() async -> Bool
}

protocol SubscriptionStatusChecker: AnyObject {
  // TODO: Should this be async?
  func isSubscribed(toEntitlements entitlements: Set<Entitlement>) -> Bool
}

// TODO: Add generics to make sure the correct StoreProduct is purchased rather than guards
struct StoreKitCoordinator {
  let productPurchaser: ProductPurchaser
  let productFetcher: ProductsFetcher
  let txnChecker: TransactionChecker
  let txnRestorer: TransactionRestorer

  // Using unowned here because we will always have a subscriptionStatusHandler
  // but since this is the class that created the coordinator, we don't want to
  // create a strong reference cycle.
  unowned var subscriptionStatusHandler: SubscriptionStatusChecker

  init(
    purchasingDelegateAdapter: SuperwallPurchasingDelegateAdapter,
    subscriptionStatusHandler: StoreKitManager,
    finishTransactions: Bool
  ) {
    let hasDelegate = purchasingDelegateAdapter.hasDelegate

    if hasDelegate {
      // If delegate exists, finishTransactions will always be false.
      if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
        // TODO: Check this, we need to make sure that SK1 and SK2 don't interfere!
        // TODO: Check that someone can purchase using RevenueCat in SK2 but restore purchases using our SK1 handler.
        // Have to rely on the delegate to purchase because
        self.productPurchaser = purchasingDelegateAdapter
        self.productFetcher = ProductsFetcherSK1()
        self.txnChecker = ProductPurchaserSK2()
        self.txnRestorer = purchasingDelegateAdapter
        self.subscriptionStatusHandler = purchasingDelegateAdapter

      } else {
        self.productPurchaser = purchasingDelegateAdapter
        self.productFetcher = ProductsFetcherSK1()
        self.txnChecker = ProductPurchaserSK1()
        self.txnRestorer = purchasingDelegateAdapter
        self.subscriptionStatusHandler = purchasingDelegateAdapter
      }
    } else {
      if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
        if finishTransactions {
          let purchaser = ProductPurchaserSK2()
          self.productPurchaser = purchaser
          self.productFetcher = ProductsFetcherSK2()
          self.txnChecker = purchaser
          self.txnRestorer = purchaser
          self.subscriptionStatusHandler = subscriptionStatusHandler
        } else {
          let purchaser = ProductPurchaserSK1()
          self.productPurchaser = purchaser
          self.productFetcher = ProductsFetcherSK1()
          self.txnChecker = purchaser
          self.txnRestorer = purchaser
          self.subscriptionStatusHandler = subscriptionStatusHandler
        }
      } else {
        // Regardless of finishing transactions.
        let purchaser = ProductPurchaserSK1()
        self.productPurchaser = purchaser
        self.productFetcher = ProductsFetcherSK1()
        self.txnChecker = purchaser
        self.txnRestorer = purchaser
        self.subscriptionStatusHandler = subscriptionStatusHandler
      }
    }

  }
}
