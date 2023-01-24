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
    lastTransaction: SKPaymentTransaction,
    withProductId productId: String,
    since startAt: Date?
  ) throws {
    guard lastTransaction.payment.productIdentifier == productId else {
      throw PurchaseError.noTransactionDetected
    }
    guard lastTransaction.transactionState == .purchased else {
      throw PurchaseError.noTransactionDetected
    }
    if let startAt = startAt,
      let lastTransactionDate = lastTransaction.transactionDate {
      guard lastTransactionDate >= startAt else {
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
