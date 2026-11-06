//
//  ObserverModeTracker.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

/// Tracks the purchases the app makes itself when `shouldObservePurchases`
/// is on.
///
/// What it remembers lives in an ``ObserverModeStore``, changed only by
/// ``ObserverModeAction``s, with this class as their context. Async work
/// (reading StoreKit 2, looking up products and tracking) runs one step at a
/// time on a ``SerialTaskCoordinator``, like Android's `SequentialActor`.
final class ObserverModeTracker: ObserverModeContext, @unchecked Sendable {
  typealias Factory = OptionsFactory
    & PurchasedTransactionsFactory
    & TransactionManagerFactory

  let store: ObserverModeStore
  /// Runs the async steps one at a time, in order.
  let operations = SerialTaskCoordinator()
  let allTransactionsProvider: AllTransactionsProviderType
  let productsManager: ProductsManager
  let factory: Factory
  private let storage: Storage

  init(
    storage: Storage,
    productsManager: ProductsManager,
    allTransactionsProvider: AllTransactionsProviderType = SK2AllTransactionsProvider(),
    factory: Factory
  ) {
    self.storage = storage
    self.productsManager = productsManager
    self.allTransactionsProvider = allTransactionsProvider
    self.factory = factory
    let didRecordLegacy = storage.get(DidCacheLegacyTransactions.self) ?? false
    store = ObserverModeStore(
      initial: ObserverModeState(
        purchasingProductIds: storage.get(PurchasingProductIds.self) ?? [],
        handledTransactionIds: storage.get(SK2TransactionIds.self) ?? [],
        legacyRecording: didRecordLegacy ? .recorded : .notRecorded
      )
    )
  }

  var state: ObserverModeState {
    store.state
  }

  // MARK: - Calls from the purchase flow

  /// Starts observing a StoreKit 1 purchase the app started, unless it's
  /// already being observed, such as a purchase put back on the queue.
  /// Returns once the purchase is being followed.
  func observeSK1Purchase(ofProductId productId: String) async {
    let outcome = store.dispatch(ObserverModeAction.sk1PurchaseStarted(productId: productId), in: self)
    if outcome == .startedObserving {
      await operations.flush()
    }
  }

  /// Forgets the StoreKit 1 purchases of products whose transactions left
  /// the payment queue.
  func removeFromQueue(productIds: Set<String>) {
    store.dispatch(ObserverModeAction.sk1TransactionsLeftQueue(productIds: productIds), in: self)
  }

  /// Marks the transactions of a purchase made through Superwall as handled,
  /// so detection doesn't track them again.
  func markSynced(transactionIds: Set<UInt64>) {
    store.dispatch(ObserverModeAction.sdkPurchaseCompleted(transactionIds: transactionIds), in: self)
  }

  /// Records the transactions made before observer mode was turned on, the
  /// first time it's on, so detection doesn't track them.
  func cacheLegacyTransactions() {
    operations.enqueue { [weak self] in
      await self?.recordLegacyTransactions()
    }
  }

  /// Tracks the latest StoreKit 2 purchase if the app made it itself and it
  /// hasn't been handled yet. Returns once it's been tracked. Detections run
  /// one at a time, after the legacy transactions have been recorded.
  func detectUnobservedTransactions() async {
    await operations.run { [weak self] in
      await self?.detectUnobservedPurchase()
    }
    // Waits for the tracking the detection queued.
    await operations.flush()
  }

  // MARK: - ObserverModeContext

  var observesPurchases: Bool {
    factory.makeSuperwallOptions().shouldObservePurchases
  }

  var isPurchaseInProgress: Bool {
    factory.makePurchasingCoordinator().hasPurchaseInProgress
  }

  func save(_ state: ObserverModeState) {
    storage.save(state.purchasingProductIds, forType: PurchasingProductIds.self)
    storage.save(state.handledTransactionIds, forType: SK2TransactionIds.self)
    storage.save(state.legacyRecording == .recorded, forType: DidCacheLegacyTransactions.self)
  }

  func startObserving(productId: String) {
    operations.enqueue { [weak self] in
      await self?.followSK1Purchase(ofProductId: productId)
    }
  }

  func trackObservedPurchase(_ transaction: ObservedTransaction) {
    operations.enqueue { [weak self] in
      await self?.trackSK2Purchase(transaction)
    }
  }

  // MARK: - Lane steps

  private func product(withId productId: String) async -> StoreProduct? {
    return try? await productsManager.products(
      identifiers: [productId],
      forPaywall: nil,
      placement: nil
    ).first
  }

  private func followSK1Purchase(ofProductId productId: String) async {
    guard let storeProduct = await product(withId: productId) else {
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

  private func trackSK2Purchase(_ transaction: ObservedTransaction) async {
    guard let product = await product(withId: transaction.productId) else {
      return
    }
    let transactionManager = factory.makeTransactionManager()
    await transactionManager.prepareToPurchase(
      product: product,
      purchaseSource: .observeFunc(product)
    )
    await factory.makePurchasingCoordinator().setIsFreeTrialAvailable(to: transaction.startedOffer)
    await transactionManager.didPurchase()
  }
}
