//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import Foundation
import StoreKit

final class ProductPurchaserSK1: NSObject {
  private var lastTransaction: SKPaymentTransaction?
  private var purchasingProductId: String?
  private var purchaseCompletion: ((PurchaseResult) -> Void)?
  private var restoreCompletion: ((Bool) -> Void)?

  private unowned let storeKitManager: StoreKitManager
  private unowned let sessionEventsManager: SessionEventsManager
  private let factory: StoreTransactionFactory

  enum StoreError: Error {
    case failedVerification
  }

  deinit {
    SKPaymentQueue.default().remove(self)
  }

  init(
    storeKitManager: StoreKitManager,
    sessionEventsManager: SessionEventsManager,
    factory: StoreTransactionFactory
  ) {
    self.storeKitManager = storeKitManager
    self.sessionEventsManager = sessionEventsManager
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
    guard let product = product.sk1Product else {
      return .failed(PurchaseError.productUnavailable)
    }

    purchasingProductId = product.productIdentifier

    return await withCheckedContinuation { continuation in
      let payment = SKPayment(product: product)
      self.purchaseCompletion = { [weak self] result in
        guard let self = self else {
          return
        }
        self.purchasingProductId = nil
        continuation.resume(returning: result)
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
    guard let lastTransaction = lastTransaction else {
      throw PurchaseError.noTransactionDetected
    }
    guard lastTransaction.payment.productIdentifier == productId else {
      throw PurchaseError.noTransactionDetected
    }
    guard lastTransaction.transactionState == .purchased else {
      throw PurchaseError.noTransactionDetected
    }
    guard let transactionDate = lastTransaction.transactionDate else {
      throw PurchaseError.noTransactionDetected
    }
    guard transactionDate >= startAt else {
      throw PurchaseError.noTransactionDetected
    }

    // Validation
    guard let localReceipt = try? InAppReceipt() else {
      throw PurchaseError.unverifiedTransaction
    }
    guard localReceipt.isValid else {
      throw PurchaseError.unverifiedTransaction
    }

    let storeTransaction = await factory.makeStoreTransaction(from: lastTransaction)
    self.lastTransaction = nil

    return storeTransaction
  }
}

// MARK: - TransactionRestorer
extension ProductPurchaserSK1: TransactionRestorer {
  // TODO: RESTORING NOT CALLING ANY OF THE OBSERVERS. NEED TO TEST WITH SANDBOX: https://stackoverflow.com/questions/64278964/xcode-12-ios-14-storekit-restore-purchase-testing
  func restorePurchases() async -> Bool {
    return await withCheckedContinuation { continuation in
      SKPaymentQueue.default().restoreCompletedTransactions()
      restoreCompletion = { completed in
        return continuation.resume(returning: completed)
      }
    }
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
    //TODO: Why is this called before transactions?
    restoreCompletion?(true)
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
    restoreCompletion?(false)
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    Task {
      let isPaywallPresented = await Superwall.shared.isPaywallPresented
      for transaction in transactions {
        lastTransaction = transaction
        updatePurchaseCompletionBlock(for: transaction)
        await checkForRestoration(transaction, isPaywallPresented: isPaywallPresented)
        finishIfPossible(transaction)

        Task(priority: .background) {
          await record(transaction)
        }
      }
      await loadPurchasedProductsIfPossible(from: transactions)
    }
  }

  // MARK: - Private API

  /// Loads purchased products in the StoreKitManager if a purchase or restore has occurred.
  private func loadPurchasedProductsIfPossible(from transactions: [SKPaymentTransaction]) async {
    if transactions.first(
      where: { $0.transactionState == .purchased || $0.transactionState == .restored }
    ) == nil {
      return
    }
    await storeKitManager.loadPurchasedProducts()
  }

  /// Sends a `PurchaseResult` to the completion block if a product has been purchased.
  private func updatePurchaseCompletionBlock(for transaction: SKPaymentTransaction) {
    guard purchasingProductId == transaction.payment.productIdentifier else {
      return
    }
    switch transaction.transactionState {
    case .purchased:
      Task {
        purchaseCompletion?(.purchased)
        purchaseCompletion = nil
      }
    case .failed:
      if let error = transaction.error {
        if let error = error as? SKError {
          switch error.code {
          case .overlayTimeout,
            .paymentCancelled,
            .overlayCancelled:
            purchaseCompletion?(.cancelled)
            purchaseCompletion = nil
            return
          default:
            break
          }
        }
        purchaseCompletion?(.failed(error))
        purchaseCompletion = nil
      }
    case .deferred:
      // TODO: Are we going to track pending subscriptions as a transaction or not? Currently it doesn't.
      purchaseCompletion?(.pending)
      purchaseCompletion = nil
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

  /// Finishes transactions if the transaction state is appropriate and
  /// ``SuperwallOptions/finishTransactions`` is `true`.
  private func finishIfPossible(_ transaction: SKPaymentTransaction) {
    // TODO: Check what happens here with a purchasing delegate. If we have a deleagte should we set finish transactions to false or something else?
    guard Superwall.options.finishTransactions else {
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
}
