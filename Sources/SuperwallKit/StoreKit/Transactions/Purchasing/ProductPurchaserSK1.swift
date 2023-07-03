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
  actor Purchasing {
    private var completion: ((PurchaseResult) -> Void)?
    private var productId: String?

    func productId(is productId: String) -> Bool {
      return productId == self.productId
    }

    func setCompletion(_ completion: @escaping (PurchaseResult) -> Void) {
      self.completion = completion
    }

    func setProductId(_ productId: String) {
      self.productId = productId
    }

    func completePurchase(result: PurchaseResult) {
      completion?(result)
      self.completion = nil
      self.productId = nil
    }
  }
  private let purchasing = Purchasing()

  // MARK: Restoration
  final class Restoration {
    var completion: ((Error?) -> Void)?
    var dispatchGroup = DispatchGroup()
    /// Used to serialise the async `SKPaymentQueue` calls when restoring.
    var queue = DispatchQueue(
      label: "com.superwall.restoration",
      qos: .userInitiated
    )
  }
  private let restoration = Restoration()

  /// The latest transaction, used for purchasing and verifying purchases.
  private var latestTransaction: SKPaymentTransaction?

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
    guard let sk1Product = product.sk1Product else {
      return .failed(PurchaseError.productUnavailable)
    }

    await purchasing.setProductId(product.productIdentifier)

    let task = Task {
      return await withCheckedContinuation { continuation in
        Task {
          await purchasing.setCompletion { result in
            continuation.resume(returning: result)
          }
        }
      }
    }
    let payment = SKPayment(product: sk1Product)
    SKPaymentQueue.default().add(payment)

    return await task.value
  }
}

// MARK: - TransactionChecker
extension ProductPurchaserSK1: TransactionChecker {
  /// Checks that a product has been purchased based on the last transaction
  /// received on the queue. If user is not using a ``PurchaseController``, it
  /// checks that the receipts are valid.
  ///
  /// The receipts are updated on successful purchase.
  ///
  /// Read more in [Apple's docs](https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/choosing_a_receipt_validation_technique#//apple_ref/doc/uid/TP40010573).
  func getAndValidateLatestTransaction(
    of productId: String,
    hasPurchaseController: Bool
  ) async throws -> StoreTransaction? {
    if hasPurchaseController {
      if let latestTransaction = latestTransaction {
        let storeTransaction = await factory.makeStoreTransaction(from: latestTransaction)
        return storeTransaction
      }
      return nil
    }

    guard let latestTransaction = latestTransaction else {
      throw PurchaseError.noTransactionDetected
    }

    try ProductPurchaserLogic.validate(
      transaction: latestTransaction,
      withProductId: productId
    )

    let storeTransaction = await factory.makeStoreTransaction(from: latestTransaction)
    self.latestTransaction = nil

    return storeTransaction
  }
}

// MARK: - TransactionRestorer
extension ProductPurchaserSK1: TransactionRestorer {
  func restorePurchases() async -> RestorationResult {
    let result = await withCheckedContinuation { continuation in
      // Using restoreCompletedTransactions instead of just refreshing
      // the receipt so that RC can pick up on the restored products,
      // if observing. It will also refresh the receipt on device.
      restoration.completion = { completed in
        return continuation.resume(returning: completed)
      }
      SKPaymentQueue.default().restoreCompletedTransactions()
    }
    restoration.completion = nil
    return result == nil ? .restored : .failed(result)
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
    restoration.dispatchGroup.notify(queue: restoration.queue) { [weak self] in
      self?.restoration.completion?(nil)
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
    restoration.dispatchGroup.notify(queue: restoration.queue) { [weak self] in
      self?.restoration.completion?(error)
    }
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    restoration.dispatchGroup.enter()
    Task {
      let isPaywallPresented = Superwall.shared.isPaywallPresented
      let paywallViewController = Superwall.shared.paywallViewController
      for transaction in transactions {
        latestTransaction = transaction
        await checkForTimeout(of: transaction, in: paywallViewController)
        await updatePurchaseCompletionBlock(for: transaction)
        await checkForRestoration(transaction, isPaywallPresented: isPaywallPresented)
        finishIfPossible(transaction)

        Task(priority: .background) {
          await record(transaction)
        }
      }
      await loadPurchasedProductsIfPossible(from: transactions)
      restoration.dispatchGroup.leave()
    }
  }

  // MARK: - Private API

  private func checkForTimeout(
    of transaction: SKPaymentTransaction,
    in paywallViewController: PaywallViewController?
  ) async {
    guard #available(iOS 14, *) else {
      return
    }
    guard let paywallViewController = paywallViewController else {
      return
    }
    switch transaction.transactionState {
    case .failed:
      if let error = transaction.error {
        if let error = error as? SKError {
          switch error.code {
          case .overlayTimeout:
            let trackedEvent = await InternalSuperwallEvent.Transaction(
              state: .timeout,
              paywallInfo: paywallViewController.info,
              product: nil,
              model: nil
            )
            await Superwall.shared.track(trackedEvent)
          default:
            break
          }
        }
      }
    default:
      break
    }
  }

  /// Sends a `PurchaseResult` to the completion block and stores the latest purchased transaction.
  private func updatePurchaseCompletionBlock(for transaction: SKPaymentTransaction) async {
    guard await purchasing.productId(is: transaction.payment.productIdentifier) else {
      return
    }

    switch transaction.transactionState {
    case .purchased:
      await purchasing.completePurchase(result: .purchased)
    case .failed:
      if let error = transaction.error {
        if let error = error as? SKError {
          switch error.code {
          case .paymentCancelled,
            .overlayCancelled:
            return await purchasing.completePurchase(result: .cancelled)
          default:
            break
          }

          if #available(iOS 14, *) {
            switch error.code {
            case .overlayTimeout:
              return await purchasing.completePurchase(result: .cancelled)
            default:
              break
            }
          }
        }
        await purchasing.completePurchase(result: .failed(error))
      }
    case .deferred:
      await purchasing.completePurchase(result: .pending)
    default:
      break
    }
  }

  /// Updates the session event for any restored product.
  private func checkForRestoration(
    _ transaction: SKPaymentTransaction,
    isPaywallPresented: Bool
  ) async {
    guard let product = await storeKitManager.productsById[transaction.payment.productIdentifier] else {
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

  /// Finishes transactions only if the delegate doesn't return a ``PurchaseController``.
  private func finishIfPossible(_ transaction: SKPaymentTransaction) {
    if delegateAdapter.hasPurchaseController {
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
