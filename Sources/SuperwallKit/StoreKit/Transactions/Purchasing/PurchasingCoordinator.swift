//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/09/2023.
//

import Foundation
import StoreKit

/// An actor that manages and coordinates the storing of types associated with purchasing.
actor PurchasingCoordinator {
  private var completion: ((PurchaseResult) -> Void)?
  var productId: String?
  var lastInternalTransaction: SKPaymentTransaction?
  var purchaseDate: Date?
  var transactions: [String: SKPaymentTransaction] = [:]

  /// A boolean indicating whether the given `date` is within an hour of the `purchaseDate`.
  func dateIsWithinLastHour(_ date: Date?) -> Bool {
    guard
      let date = date,
      let transactionDate = purchaseDate
    else {
      return false
    }
    let oneHourBeforePurchase = date.addingTimeInterval(-3600)
    return oneHourBeforePurchase.compare(transactionDate) == .orderedAscending
  }

  func setCompletion(_ completion: @escaping (PurchaseResult) -> Void) {
    self.completion = completion
  }

  func beginPurchase(of productId: String) {
    self.purchaseDate = Date()
    self.productId = productId
  }

  /// Gets the latest transaction of a specified product ID.
  func getLatestTransaction(
    forProductId productId: String,
    factory: StoreTransactionFactory
  ) async -> StoreTransaction? {
    // Get the date a purchase was initiated. This can never be nil after
    // a purchase.
    guard let purchaseDate = purchaseDate else {
      return nil
    }

    // If on iOS 15+, try and get latest transaction using SK2.
    if #available(iOS 15.0, *) {
      if let verificationResult = await Transaction.latest(
        for: productId,
        since: purchaseDate
      ) {
        // Skip verification step as this has already been done.
        let transaction = verificationResult.unsafePayloadValue
        return await factory.makeStoreTransaction(from: transaction)
      }
    }

    // If no transaction retrieved, try to get last transaction if
    // the SDK handled purchasing.
    if let transaction = lastInternalTransaction {
      return await factory.makeStoreTransaction(from: transaction)
    }

    func getLastExternalStoreTransaction() async -> StoreTransaction? {
      if let transaction = transactions[productId],
        dateIsWithinLastHour(transaction.transactionDate) {
        return await factory.makeStoreTransaction(from: transaction)
      }
      return nil
    }

    // Otherwise get the last externally purchased transaction from the payment queue.
    if let transaction = await getLastExternalStoreTransaction() {
      return transaction
    }

    // If still no transaction, wait 500ms and try again before returning nil.
    try? await Task.sleep(nanoseconds: 500_000_000)

    if let transaction = await getLastExternalStoreTransaction() {
      return transaction
    }

    return nil
  }

  /// Stores the transaction if purchased and is the latest for a specific product ID.
  /// This is used as a fallback if we can't retrieve the transaction using SK2.
  func storeIfPurchased(_ transaction: SK1Transaction) async {
    guard case .purchased = transaction.transactionState else {
      return
    }
    let productId = transaction.payment.productIdentifier

    // If there is an existing transaction, which has a transaction date...
    if let existingTransaction = transactions[productId],
      let existingTransactionDate = existingTransaction.transactionDate {
      // And if the new transaction date was after the stored transaction, update.
      // Else, ignore.
      if transaction.transactionDate?.compare(existingTransactionDate) == .orderedDescending {
        transactions[productId] = transaction
      }
    } else {
      // If there isn't an existing transaction, store.
      transactions[productId] = transaction
    }
  }

  func completePurchase(
    of transaction: SK1Transaction,
    result: PurchaseResult
  ) {
    // Only complete if the product ID of the transaction is the same as
    // the purchasing transaction.
    guard productId == transaction.payment.productIdentifier else {
      return
    }
    // If the transaction completed a purchase, check it is within the last
    // hour since starting purchase. Otherwise old purchased products may come
    // through and complete the purchase.
    if result == .purchased {
      guard dateIsWithinLastHour(transaction.transactionDate) else {
        return
      }
    }
    lastInternalTransaction = transaction
    completion?(result)
    completion = nil
    productId = nil
  }
}
