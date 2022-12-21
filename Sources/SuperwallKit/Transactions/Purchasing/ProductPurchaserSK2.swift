//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import Foundation
import StoreKit

@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final class ProductPurchaserSK2: ProductPurchaser {
  private var updates: Task<Void, Never>?
  private let storeKitManager: StoreKitManager
  private let sessionEventsManager: SessionEventsManager

  init(
    storeKitManager: StoreKitManager,
    sessionEventsManager: SessionEventsManager
  ) {
    self.storeKitManager = storeKitManager
    self.sessionEventsManager = sessionEventsManager
    observeTransactionUpdates()
  }

  deinit {
    cancelTasks()
  }

  func cancelTasks() {
    // Cancel the update handling task when you deinitialize the class.
    updates?.cancel()
  }

  func purchase(product: StoreProduct) async -> PurchaseResult {
    guard let product = product.sk2Product else {
      return .failed(PurchaseError.productUnavailable)
    }

    let result: StoreKit.Product.PurchaseResult

    do {
      result = try await product.purchase()
    } catch {
      return .failed(error)
    }

    switch result {
    case let .success(verificationResult):
      switch verificationResult {
      case let .unverified(_, verificationError):
        return .failed(verificationError)
      case .verified(let transaction):
        // TODO: Check that transaction should always be finished
        await transaction.finish()
        return .purchased
      }
    case .pending:
      // TODO: Figure out whether this should count as a transaction. We need to finish unfinished transactions from this!
      return .pending
    case .userCancelled:
      return .cancelled
    default:
      return .failed(PurchaseError.unknown)
    }
  }

  private func observeTransactionUpdates() {
    updates = Task(priority: .background) {
      for await verificationResult in Transaction.updates {
        guard case .verified(let transaction) = verificationResult else {
          return
        }
        // Change this to not use Superwall.options
        if Superwall.options.finishTransactions {
          await transaction.finish()
        }
        let storeTransaction = await StoreTransaction.create(from: transaction)
        await sessionEventsManager.enqueue(storeTransaction)
      }
    }
  }
}

// MARK: - TransactionChecker
@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension ProductPurchaserSK2: TransactionChecker {
  /// An iOS 15-only function that checks for a transaction of the product.
  ///
  /// We need this function because on iOS 15+, the `Transaction.updates` listener doesn't notify us
  /// of transactions for recent purchases.
  func getAndValidateTransaction(
    of productId: String,
    since purchaseStartDate: Date
  ) async throws -> StoreTransaction {
    let transaction = await Transaction.latest(for: productId)
    guard case let .verified(transaction) = transaction else {
      throw PurchaseError.unverifiedTransaction
    }
    guard transaction.purchaseDate >= purchaseStartDate else {
      throw PurchaseError.noTransactionDetected
    }
    return await StoreTransaction.create(from: transaction)
  }
}

// MARK: - TransactionRestorer
@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension ProductPurchaserSK2: TransactionRestorer {
  func restorePurchases() async -> Bool {
    return await storeKitManager.refreshReceipt()
  }
}
