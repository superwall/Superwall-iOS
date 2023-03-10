//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/01/2023.
//

import Foundation
import StoreKit

@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final class TransactionVerifierSK2: TransactionChecker {
  let factory: StoreTransactionFactory

  init(factory: StoreTransactionFactory) {
    self.factory = factory
  }
  /// An iOS 15+-only function that checks for a transaction of the product.
  ///
  /// We need this function because on iOS 15+, the `Transaction.updates` listener doesn't notify us
  /// of transactions for recent purchases.
  func getAndValidateLatestTransaction(
    of productId: String,
    since purchaseStartDate: Date? = nil
  ) async throws -> StoreTransaction {
    let transaction = await Transaction.latest(for: productId)
    guard case let .verified(transaction) = transaction else {
      throw PurchaseError.unverifiedTransaction
    }
    if let purchaseStartDate = purchaseStartDate {
      guard transaction.purchaseDate >= purchaseStartDate else {
        throw PurchaseError.noTransactionDetected
      }
    }
    return await factory.makeStoreTransaction(from: transaction)
  }
}
