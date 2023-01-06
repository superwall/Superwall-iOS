//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/12/2022.
//

import Foundation

/// Coordinates: The purchasing, restoring and retrieving of products; the checking
/// of transactions; and the determining of the user's subscription status.
///
/// We can't use StoreKit 2 because:
/// 1. If there are unfinished StoreKit transaction updates on app open, only the first
///    listener is given the updates. This means that our listener can interfere with
///    the clients listener (if they're using SK2) and their transactions may not even show up!
/// 2. If the developer used an SK1 listener, their listener could finish the txns before
///    ours. Which means that we will never see the unfinished transactions or we'll see only
///    a few of them.
/// 3. The Transaction.updates listener is not reliably called for transactions made outside
///   the app. Therefore the transactions aren't always finished.
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
    factory: StoreTransactionFactory & ProductPurchaserFactory
  ) {
    let hasDelegate = purchasingDelegateAdapter.hasDelegate

    if hasDelegate {
      self.productPurchaser = purchasingDelegateAdapter
      self.productFetcher = ProductsFetcherSK1()
      self.txnChecker = factory.makeSK1ProductPurchaser()
      self.txnRestorer = purchasingDelegateAdapter
      self.subscriptionStatusHandler = purchasingDelegateAdapter
    } else {
      let purchaser = factory.makeSK1ProductPurchaser()
      self.productPurchaser = purchaser
      self.productFetcher = ProductsFetcherSK1()
      self.txnChecker = purchaser
      self.txnRestorer = purchaser
      self.subscriptionStatusHandler = storeKitManager
    }
  }
}
