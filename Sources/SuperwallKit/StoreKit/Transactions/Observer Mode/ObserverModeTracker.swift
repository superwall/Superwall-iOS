//
//  ObserverModeTracker.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

/// Tracks the purchases the app makes itself when `shouldObservePurchases`
/// is on, keeping what it knows about them in an ``ObserverModeStore``.
///
/// The store is read and changed with its lock held, and saved by an observer
/// that only hands the write to storage's background queue. Product lookups
/// and tracking happen outside the lock. StoreKit 2 detection runs one at a
/// time on a ``SerialTaskCoordinator``, behind the caching of the transactions
/// made before observer mode was turned on.
final class ObserverModeTracker: ObserverModeContext, @unchecked Sendable {
  typealias Factory = OptionsFactory
    & PurchasedTransactionsFactory
    & TransactionManagerFactory

  let store: ObserverModeStore
  let allTransactionsProvider: AllTransactionsProviderType
  let factory: Factory
  /// Runs the StoreKit 2 legacy caching and detection one at a time.
  let operations = SerialTaskCoordinator()
  let productsManager: ProductsManager

  init(
    storage: Storage,
    productsManager: ProductsManager,
    allTransactionsProvider: AllTransactionsProviderType = SK2AllTransactionsProvider(),
    factory: Factory
  ) {
    self.productsManager = productsManager
    self.allTransactionsProvider = allTransactionsProvider
    self.factory = factory
    store = ObserverModeStore(
      initial: ObserverModeState(
        purchasingProductIds: storage.get(PurchasingProductIds.self) ?? [],
        syncedTransactionIds: storage.get(SK2TransactionIds.self) ?? [],
        didCacheLegacyTransactions: storage.get(DidCacheLegacyTransactions.self) ?? false
      )
    )

    // Saving only hands the write to storage's queue, so it's safe with the
    // store locked, and the saves happen in the order the changes did.
    store.observe { before, after in
      if after.purchasingProductIds != before.purchasingProductIds {
        storage.save(after.purchasingProductIds, forType: PurchasingProductIds.self)
      }
      if after.syncedTransactionIds != before.syncedTransactionIds {
        storage.save(after.syncedTransactionIds, forType: SK2TransactionIds.self)
      }
      if after.didCacheLegacyTransactions != before.didCacheLegacyTransactions {
        storage.save(after.didCacheLegacyTransactions, forType: DidCacheLegacyTransactions.self)
      }
    }
  }

  var state: ObserverModeState {
    store.state
  }

  // MARK: - StoreKit 1

  /// Starts observing a StoreKit 1 purchase the app started, unless it's
  /// already being observed, such as a purchase put back on the queue.
  func observeSK1Purchase(ofProductId productId: String) async {
    var isNew = false
    store.dispatch(
      ObserverModeAction.claimSK1Purchase(productId: productId) { isNew = $0 },
      in: self
    )
    if !isNew {
      return
    }

    guard
      let storeProduct = try? await productsManager.products(
        identifiers: [productId],
        forPaywall: nil,
        placement: nil
      ).first
    else {
      Logger.debug(
        logLevel: .debug,
        scope: .superwallCore,
        message: "There's a purchase happening of a product with id \(productId), "
          + "but we couldn't retrieve it to observe its purchase."
      )
      return
    }
    let transactionManager = factory.makeTransactionManager()
    await transactionManager.prepareToPurchase(
      product: storeProduct,
      purchaseSource: .observeFunc(storeProduct)
    )
    await factory.makePurchasingCoordinator().setCompletion { [weak transactionManager] result in
      Task {
        await transactionManager?.handle(
          result: result,
          state: .observing
        )
      }
    }
  }

  /// Forgets the StoreKit 1 purchases of products whose transactions left
  /// the payment queue.
  func removeFromQueue(productIds: Set<String>) {
    store.update(ObserverModeUpdate.removedFromQueue(productIds: productIds))
  }

  // MARK: - StoreKit 2

  /// Marks StoreKit 2 transactions as handled, so detection doesn't track
  /// them again. Does nothing unless the SDK observes purchases.
  func markSynced(transactionIds: Set<UInt64>) {
    if !factory.makeSuperwallOptions().shouldObservePurchases {
      return
    }
    store.update(ObserverModeUpdate.synced(transactionIds: transactionIds))
  }
}
