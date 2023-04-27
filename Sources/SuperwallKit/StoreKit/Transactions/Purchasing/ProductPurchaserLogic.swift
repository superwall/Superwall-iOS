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
    transaction: SKPaymentTransaction,
    withProductId productId: String
  ) throws {
    guard transaction.payment.productIdentifier == productId else {
      throw PurchaseError.noTransactionDetected
    }
    guard transaction.transactionState == .purchased else {
      throw PurchaseError.noTransactionDetected
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
