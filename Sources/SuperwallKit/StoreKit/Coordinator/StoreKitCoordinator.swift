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
  /// Fetches the products.
  let productFetcher: ProductsFetcher

  /// Gets and validates transactions.
  let txnChecker: TransactionChecker & ProductPurchaser & TransactionRestorer

  /// Purchases the product.
  var productPurchaser: ProductPurchaser

  /// Restores purchases.
  var txnRestorer: TransactionRestorer

  /// Checks if the user is subscribed.
  unowned var subscriptionStatusHandler: SubscriptionStatusChecker
  unowned let delegateAdapter: SuperwallDelegateAdapter
  unowned let storeKitManager: StoreKitManager

  init(
    delegateAdapter: SuperwallDelegateAdapter,
    storeKitManager: StoreKitManager,
    factory: StoreTransactionFactory & ProductPurchaserFactory,
    productsFetcher: ProductsFetcher = ProductsFetcherSK1()
  ) {
    self.delegateAdapter = delegateAdapter
    self.storeKitManager = storeKitManager
    self.productFetcher = productsFetcher

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

  /// Updates which classes handle subscription-related logic.
  ///
  /// Called when a user updates the delegate.
  mutating func didToggleDelegate() {
    let hasSubscriptionController = delegateAdapter.hasSubscriptionController
    if hasSubscriptionController {
      self.productPurchaser = delegateAdapter
      self.txnRestorer = delegateAdapter
      self.subscriptionStatusHandler = delegateAdapter
    } else {
      self.productPurchaser = txnChecker
      self.txnRestorer = txnChecker
      self.subscriptionStatusHandler = storeKitManager
    }
  }
}
