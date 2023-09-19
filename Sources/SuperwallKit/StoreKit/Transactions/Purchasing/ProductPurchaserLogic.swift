//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/01/2023.
//

import Foundation
import StoreKit

enum ProductPurchaserLogic {
  /// Validates the latest transaction
  static func validate(
    transaction: SKPaymentTransaction,
    since purchaseDate: Date?,
    withProductId productId: String
  ) async throws {
    guard let purchaseDate = purchaseDate else {
      throw PurchaseError.unknown
    }

    // Get latest transaction since the purchase date using sk2.
    // Check that it's verified.
    if #available(iOS 15.0, *) {
      if let verificationResult = await Transaction.latest(
        for: productId,
        since: purchaseDate
      ) {
        guard case .verified = verificationResult else {
          throw PurchaseError.unverifiedTransaction
        }
        return
      }
    }

    // Otherwise, check that the local receipt is valid.
    guard transaction.payment.productIdentifier == productId else {
      throw PurchaseError.noTransactionDetected
    }
    guard transaction.transactionState == .purchased else {
      throw PurchaseError.noTransactionDetected
    }

    guard let localReceipt = try? InAppReceipt() else {
      throw PurchaseError.unverifiedTransaction
    }
    guard localReceipt.isValid else {
      throw PurchaseError.unverifiedTransaction
    }
  }
}
