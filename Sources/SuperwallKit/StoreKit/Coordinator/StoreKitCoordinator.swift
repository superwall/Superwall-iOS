//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/12/2022.
//

import Foundation

/// Coordinates: The purchasing, restoring and retrieving of products; the checking
/// of transactions; and the determining of the user's subscription status.
struct StoreKitCoordinator {
  /// Purchases the product.
  let productPurchaser: ProductPurchaser

  /// Fetches the products.
  let productFetcher: ProductsFetcher

  /// Gets and validates transactions.
  let txnChecker: TransactionChecker

  /// Restores purchases.
  let txnRestorer: TransactionRestorer

  // Using unowned here because we will always have a subscriptionStatusHandler
  // but since this is sometimes the class that created the coordinator, we
  // don't want to create a strong reference cycle.
  /// Checks if the user is subscribed.
  unowned let subscriptionStatusHandler: SubscriptionStatusChecker

  init(
    purchasingDelegateAdapter: SuperwallPurchasingDelegateAdapter,
    storeKitManager: StoreKitManager,
    finishTransactions: Bool,
    sessionEventsManager: SessionEventsManager,
    factory: StoreTransactionFactory
  ) {
    let hasDelegate = purchasingDelegateAdapter.hasDelegate

    if hasDelegate {
      // If delegate exists, finishTransactions will always be false and SK1 must be used.
      // After testing, it turns out we can't use SK2 here because:
      // 1. If there are unfinished StoreKit transaction updates on app open, only the first
      //    listener is given the updates. This means that our listener can interfere with
      //    the clients listener (if they're using SK2) and their transactions may not even show up!
      // 2. If they use an SK1 listener, their listener could finish the txns before
      //    ours. Which means that we will never see the unfinished transactions.
      self.productPurchaser = purchasingDelegateAdapter
      self.productFetcher = ProductsFetcherSK1()
      self.txnChecker = ProductPurchaserSK1(
        storeKitManager: storeKitManager,
        sessionEventsManager: sessionEventsManager,
        factory: factory
      )
      self.txnRestorer = purchasingDelegateAdapter
      self.subscriptionStatusHandler = purchasingDelegateAdapter
    } else {
      if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
        if finishTransactions {
          let purchaser = ProductPurchaserSK2(
            storeKitManager: storeKitManager,
            sessionEventsManager: sessionEventsManager,
            factory: factory
          )
          self.productPurchaser = purchaser
          self.productFetcher = ProductsFetcherSK2()
          self.txnChecker = purchaser
          self.txnRestorer = purchaser
          self.subscriptionStatusHandler = storeKitManager
        } else {
          let purchaser = ProductPurchaserSK1(
            storeKitManager: storeKitManager,
            sessionEventsManager: sessionEventsManager,
            factory: factory
          )
          self.productPurchaser = purchaser
          self.productFetcher = ProductsFetcherSK1()
          self.txnChecker = purchaser
          self.txnRestorer = purchaser
          self.subscriptionStatusHandler = storeKitManager
        }
      } else {
        // We have to use SK1 on <iOS 15, regardless of whether
        // we finish transactions.
        let purchaser = ProductPurchaserSK1(
          storeKitManager: storeKitManager,
          sessionEventsManager: sessionEventsManager,
          factory: factory
        )
        self.productPurchaser = purchaser
        self.productFetcher = ProductsFetcherSK1()
        self.txnChecker = purchaser
        self.txnRestorer = purchaser
        self.subscriptionStatusHandler = storeKitManager
      }
    }
  }
}
