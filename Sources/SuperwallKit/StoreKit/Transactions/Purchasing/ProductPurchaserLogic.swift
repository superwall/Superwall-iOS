//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/01/2023.
//

import Foundation
import StoreKit

enum ProductPurchaserLogic {
  static func validate(
    latestTransaction: SKPaymentTransaction,
    withProductId productId: String,
    since purchasedAt: Date?
  ) throws {
    guard latestTransaction.payment.productIdentifier == productId else {
      throw PurchaseError.noTransactionDetected
    }
    guard latestTransaction.transactionState == .purchased else {
      throw PurchaseError.noTransactionDetected
    }
    if let purchasedAt = purchasedAt,
      let latestTransactionDate = latestTransaction.transactionDate {
      guard latestTransactionDate >= purchasedAt else {
        throw PurchaseError.noTransactionDetected
      }
    }

    // Validation
    guard let localReceipt = try? InAppReceipt() else {
      throw PurchaseError.unverifiedTransaction
    }
    guard localReceipt.isValid else {
      throw PurchaseError.unverifiedTransaction
    }
  }
}
