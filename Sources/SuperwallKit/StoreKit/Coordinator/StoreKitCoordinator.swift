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
  let txnChecker: TransactionChecker

  /// Purchases the product.
  var productPurchaser: ProductPurchaser

  /// Restores purchases.
  var txnRestorer: TransactionRestorer

  /// Checks if the user is subscribed.
  unowned let delegateAdapter: SuperwallDelegateAdapter
  unowned let storeKitManager: StoreKitManager
  private let factory: StoreTransactionFactory & ProductPurchaserFactory

  init(
    delegateAdapter: SuperwallDelegateAdapter,
    storeKitManager: StoreKitManager,
    factory: StoreTransactionFactory & ProductPurchaserFactory,
    productsFetcher: ProductsFetcher = ProductsFetcherSK1()
  ) {
    self.factory = factory
    self.delegateAdapter = delegateAdapter
    self.storeKitManager = storeKitManager
    self.productFetcher = productsFetcher

    let sk1ProductPurchaser = factory.makeSK1ProductPurchaser()

    if #available(iOS 15.0, *) {
      self.txnChecker = TransactionVerifierSK2(factory: factory)
    } else {
      self.txnChecker = sk1ProductPurchaser
    }

    let hasPurchaseController = delegateAdapter.hasPurchaseController
    if hasPurchaseController {
      self.productPurchaser = delegateAdapter
      self.txnRestorer = delegateAdapter
    } else {
      self.productPurchaser = sk1ProductPurchaser
      self.txnRestorer = sk1ProductPurchaser
    }
  }
}
