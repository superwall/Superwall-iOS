//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import Foundation
import StoreKit

final class ProductPurchaserSK1: NSObject {
  // MARK: Purchasing
  final class Purchasing {
    var completion: ((PurchaseResult) -> Void)?
    var transaction: SKPaymentTransaction?
    var productId: String?
  }
  private let purchasing = Purchasing()

  // MARK: - Restoration
  /// Used to serialise the async `SKPaymentQueue` calls when restoring.
  private let restorationQueueGroup = DispatchGroup()
  private var restoreCompletion: ((Bool) -> Void)?

  // MARK: Dependencies
  private unowned let storeKitManager: StoreKitManager
  private unowned let sessionEventsManager: SessionEventsManager
  private unowned let delegateAdapter: SuperwallDelegateAdapter
  private let factory: StoreTransactionFactory

  deinit {
    SKPaymentQueue.default().remove(self)
  }

  init(
    storeKitManager: StoreKitManager,
    sessionEventsManager: SessionEventsManager,
    delegateAdapter: SuperwallDelegateAdapter,
    factory: StoreTransactionFactory
  ) {
    self.storeKitManager = storeKitManager
    self.sessionEventsManager = sessionEventsManager
    self.delegateAdapter = delegateAdapter
    self.factory = factory
    super.init()
    SKPaymentQueue.default().add(self)
  }
}

// MARK: - ProductPurchaser
extension ProductPurchaserSK1: ProductPurchaser {
  /// Purchases a product, waiting for the completion block to be fired and
  /// returning a purchase result.
  func purchase(product: StoreProduct) async -> PurchaseResult {
    purchasing.productId = product.productIdentifier

    return await withCheckedContinuation { continuation in
      let payment = SKPayment(product: product.underlyingSK1Product)

      purchasing.completion = { [weak self] result in
        guard let self = self else {
          return
        }
        continuation.resume(returning: result)
        self.purchasing.productId = nil
        self.purchasing.completion = nil
      }
      SKPaymentQueue.default().add(payment)
    }
  }
}

// MARK: - TransactionChecker
extension ProductPurchaserSK1: TransactionChecker {
  /// Checks that a product has been purchased based on the last transaction
  /// received on the queue and that the receipts are valid.
  ///
  /// The receipts are updated on successful purchase.
  ///
  /// Read more in [Apple's docs](https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/choosing_a_receipt_validation_technique#//apple_ref/doc/uid/TP40010573).
  func getAndValidateTransaction(
    of productId: String,
    since startAt: Date
  ) async throws -> StoreTransaction {
    guard let transaction = purchasing.transaction else {
      throw PurchaseError.noTransactionDetected
    }
    try ProductPurchaserLogic.validate(
      lastTransaction: transaction,
      withProductId: productId,
      since: startAt
    )

    let storeTransaction = await factory.makeStoreTransaction(from: transaction)
    self.purchasing.transaction = nil

    return storeTransaction
  }
}

// MARK: - TransactionRestorer
extension ProductPurchaserSK1: TransactionRestorer {
  func restorePurchases() async -> Bool {
    let result = await withCheckedContinuation { continuation in
      // Using restoreCompletedTransactions instead of just refreshing
      // the receipt so that RC can pick up on the restored products,
      // if observing. It will also refresh the receipt on device.
      restoreCompletion = { completed in
        return continuation.resume(returning: completed)
      }
      SKPaymentQueue.default().restoreCompletedTransactions()
    }
    restoreCompletion = nil
    return result
  }
}

// MARK: - SKPaymentTransactionObserver
extension ProductPurchaserSK1: SKPaymentTransactionObserver {
  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Restore Completed Transactions Finished"
    )
    restorationQueueGroup.notify(queue: .main) { [weak self] in
      self?.restoreCompletion?(true)
    }
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    restoreCompletedTransactionsFailedWithError error: Error
  ) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Restore Completed Transactions Failed With Error",
      error: error
    )
    restorationQueueGroup.notify(queue: .main) { [weak self] in
      self?.restoreCompletion?(false)
    }
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    restorationQueueGroup.enter()
    Task {
      let isPaywallPresented = await Superwall.shared.isPaywallPresented
      for transaction in transactions {
        updatePurchaseCompletionBlock(for: transaction)
        await checkForRestoration(transaction, isPaywallPresented: isPaywallPresented)
        finishIfPossible(transaction)

        Task(priority: .background) {
          await record(transaction)
        }
      }
      await loadPurchasedProductsIfPossible(from: transactions)
      restorationQueueGroup.leave()
    }
  }

  // MARK: - Private API

  /// Sends a `PurchaseResult` to the completion block and stores the latest purchased transaction.
  private func updatePurchaseCompletionBlock(for transaction: SKPaymentTransaction) {
    guard purchasing.productId == transaction.payment.productIdentifier else {
      return
    }

    switch transaction.transactionState {
    case .purchased:
      purchasing.transaction = transaction
      purchasing.completion?(.purchased)
    case .failed:
      if let error = transaction.error {
        if let error = error as? SKError {
          switch error.code {
          case .overlayTimeout,
            .paymentCancelled,
            .overlayCancelled:
            purchasing.completion?(.cancelled)
            return
          default:
            break
          }
        }
        purchasing.completion?(.failed(error))
      }
    case .deferred:
      // TODO: Are we going to track pending subscriptions as a transaction or not? Currently it doesn't.
      purchasing.completion?(.pending)
    default:
      break
    }
  }

  /// Updates the session event for any restored product.
  private func checkForRestoration(
    _ transaction: SKPaymentTransaction,
    isPaywallPresented: Bool
  ) async {
    guard let product = storeKitManager.productsById[transaction.payment.productIdentifier] else {
      return
    }
    guard isPaywallPresented else {
      return
    }
    switch transaction.transactionState {
    case .restored:
      await sessionEventsManager.triggerSession.trackTransactionRestoration(
        withId: transaction.transactionIdentifier,
        product: product
      )
    default:
      break
    }
  }

  /// Finishes transactions only if the delegate doesn't return a ``SubscriptionController``.
  private func finishIfPossible(_ transaction: SKPaymentTransaction) {
    if delegateAdapter.hasSubscriptionController {
      return
    }

    switch transaction.transactionState {
    case .purchased,
        .failed,
        .restored:
      SKPaymentQueue.default().finishTransaction(transaction)
    default:
      break
    }
  }

  /// Sends the transaction to the backend.
  private func record(_ transaction: SKPaymentTransaction) async {
    let storeTransaction = await factory.makeStoreTransaction(from: transaction)
    await sessionEventsManager.enqueue(storeTransaction)
  }

  /// Loads purchased products in the StoreKitManager if a purchase or restore has occurred.
  private func loadPurchasedProductsIfPossible(from transactions: [SKPaymentTransaction]) async {
    if transactions.first(
      where: { $0.transactionState == .purchased || $0.transactionState == .restored }
    ) == nil {
      return
    }
    await storeKitManager.loadPurchasedProducts()
  }

}
