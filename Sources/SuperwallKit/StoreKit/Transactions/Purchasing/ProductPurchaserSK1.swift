//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//
// swiftlint:disable function_body_length

import Foundation
import StoreKit

final class ProductPurchaserSK1: NSObject {
  // MARK: Purchasing
  let coordinator = PurchasingCoordinator()

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

  // MARK: Dependencies
  private let storeKitManager: StoreKitManager
  private let receiptManager: ReceiptManager
  private let sessionEventsManager: SessionEventsManager
  private let identityManager: IdentityManager
  private let storage: Storage
  private let factory: HasExternalPurchaseControllerFactory & StoreTransactionFactory

  deinit {
    SKPaymentQueue.default().remove(self)
  }

  init(
    storeKitManager: StoreKitManager,
    receiptManager: ReceiptManager,
    sessionEventsManager: SessionEventsManager,
    identityManager: IdentityManager,
    storage: Storage,
    factory: HasExternalPurchaseControllerFactory & StoreTransactionFactory
  ) {
    self.storeKitManager = storeKitManager
    self.receiptManager = receiptManager
    self.sessionEventsManager = sessionEventsManager
    self.identityManager = identityManager
    self.factory = factory
    self.storage = storage

    super.init()
    SKPaymentQueue.default().add(self)
  }

  /// Purchases a product, waiting for the completion block to be fired and
  /// returning a purchase result.
  func purchase(
    product: SKProduct
  ) async -> PurchaseResult {
    let task = Task {
      return await withCheckedContinuation { continuation in
        Task {
          await coordinator.setCompletion { result in
            continuation.resume(returning: result)
          }
        }
      }
    }
    let payment = SKMutablePayment(product: product)
    payment.applicationUsername = identityManager.appUserId
    SKPaymentQueue.default().add(payment)

    return await task.value
  }

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
      let paywallViewController = Superwall.shared.paywallViewController
      let purchaseDate = await coordinator.purchaseDate
      for transaction in transactions {
        await coordinator.storeIfPurchased(transaction)
        await checkForTimeout(of: transaction, in: paywallViewController)
        await updatePurchaseCompletionBlock(for: transaction, purchaseDate: purchaseDate)
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
    switch transaction.transactionState {
    case .failed:
      if let error = transaction.error {
        if let error = error as? SKError {
          switch error.code {
          case .overlayTimeout:
            let trackedEvent = await InternalSuperwallEvent.Transaction(
              state: .timeout,
              paywallInfo: paywallViewController?.info ?? .empty(),
              product: nil,
              model: nil
            )
            await Superwall.shared.track(trackedEvent)
            await paywallViewController?.webView.messageHandler.handle(.transactionTimeout)
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
  private func updatePurchaseCompletionBlock(
    for skTransaction: SKPaymentTransaction,
    purchaseDate: Date?
  ) async {
    // Only continue if using internal purchase controller. The transaction may be
    // readded to the queue if finishing fails so we need to make sure
    // we can re-finish the transaction. It doesn't matter if purchased internally or
    // externally.
    if factory.makeHasExternalPurchaseController() {
      return
    }

    switch skTransaction.transactionState {
    case .purchased:
      do {
        try await ProductPurchaserLogic.validate(
          transaction: skTransaction,
          since: purchaseDate,
          withProductId: skTransaction.payment.productIdentifier
        )
        SKPaymentQueue.default().finishTransaction(skTransaction)

        if hasRestored(skTransaction, purchaseDate: purchaseDate) {
          await coordinator.completePurchase(
            of: skTransaction,
            result: .restored
          )
        } else {
          await coordinator.completePurchase(
            of: skTransaction,
            result: .purchased
          )
        }
      } catch {
        SKPaymentQueue.default().finishTransaction(skTransaction)
        await coordinator.completePurchase(
          of: skTransaction,
          result: .failed(error)
        )
      }
    case .failed:
      SKPaymentQueue.default().finishTransaction(skTransaction)
      if let error = skTransaction.error {
        if let error = error as? SKError {
          switch error.code {
          case .paymentCancelled,
            .overlayCancelled:
            return await coordinator.completePurchase(
              of: skTransaction,
              result: .cancelled
            )
          default:
            break
          }

          if #available(iOS 14, *) {
            switch error.code {
            case .overlayTimeout:
              await coordinator.completePurchase(
                of: skTransaction,
                result: .cancelled
              )
            default:
              break
            }
          }
        }
        await coordinator.completePurchase(
          of: skTransaction,
          result: .failed(error))
      }
    case .deferred:
      SKPaymentQueue.default().finishTransaction(skTransaction)
      await coordinator.completePurchase(of: skTransaction, result: .pending)
    case .restored:
      SKPaymentQueue.default().finishTransaction(skTransaction)
    default:
      break
    }
  }

  private func hasRestored(
    _ transaction: SKPaymentTransaction,
    purchaseDate: Date?
  ) -> Bool {
    guard let purchaseDate = purchaseDate else {
      return false
    }
    // If has a transaction date and that happened before purchase
    // button was pressed...
    if let transactionDate = transaction.transactionDate,
      transactionDate < purchaseDate {
      return true
    }

    return false
  }

  /// Loads purchased products in the StoreKitManager if a purchase or restore has occurred.
  private func loadPurchasedProductsIfPossible(from transactions: [SKPaymentTransaction]) async {
    if transactions.first(
      where: { $0.transactionState == .purchased || $0.transactionState == .restored }
    ) == nil {
      return
    }
    await receiptManager.loadPurchasedProducts()
  }
}
