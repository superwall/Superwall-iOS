//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/12/2022.
//

import Foundation

/// Coordinates the purchasing, restoring and retrieving of products; the checking
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

  /// Checks if the user is subscribed.
  unowned let subscriptionStatusHandler: SubscriptionStatusChecker

  init(
    delegateAdapter: SuperwallDelegateAdapter,
    storeKitManager: StoreKitManager,
    factory: StoreTransactionFactory & ProductPurchaserFactory
  ) {
    self.productFetcher = ProductsFetcherSK1()

    let sk1ProductPurchaser = factory.makeSK1ProductPurchaser()
    self.txnChecker = sk1ProductPurchaser

    let hasSubscriptionController = delegateAdapter.hasSubscriptionController

    if hasSubscriptionController {
      self.productPurchaser = delegateAdapter
      self.txnRestorer = delegateAdapter
      self.subscriptionStatusHandler = delegateAdapter
    } else {
      self.productPurchaser = sk1ProductPurchaser
      self.txnRestorer = sk1ProductPurchaser
      self.subscriptionStatusHandler = storeKitManager
    }
  }
}
