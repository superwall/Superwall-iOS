//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import Foundation
import StoreKit

enum PurchaseError: LocalizedError {
  case productUnavailable
  case unknown
  case noTransactionDetected
  case unverifiedTransaction

  var errorDescription: String? {
    switch self {
    case .productUnavailable:
      return "There was an error retrieving the product to purchase."
    case .noTransactionDetected:
      return "No receipt was found on device for the product transaction."
    case .unverifiedTransaction:
      return "The product transaction could not be verified."
    case .unknown:
      return "An unknown error occurred."
    }
  }
}

struct PurchaseManager {
  unowned let storeKitManager: StoreKitManager
  let hasPurchaseController: Bool

  /// Purchases the product and then checks for a transaction
  func purchase(product: StoreProduct) async -> InternalPurchaseResult {
    let purchaseStartAt = Date()

    let result = await storeKitManager.coordinator.productPurchaser.purchase(product: product)

    switch result {
    case .failed(let error):
      return .failed(error)
    case .pending:
      return .pending
    case .cancelled:
      return .cancelled
    case .purchased:
      do {
        let transaction = try await storeKitManager.coordinator.txnChecker.getAndValidateLatestTransaction(
          of: product.productIdentifier,
          hasPurchaseController: hasPurchaseController
        )
        
        if hasRestored(
          transaction,
          hasPurchaseController: hasPurchaseController,
          purchaseStartAt: purchaseStartAt
        ) {
          return .restored
        }

        return .purchased(transaction)
      } catch {
        return .failed(error)
      }
    }
  }

  /// Checks whether the purchased product was actually a restoration. This happens (in sandbox),
  /// when a user purchases, then deletes the app, then launches the paywall and purchases again.
  private func hasRestored(
    _ transaction: StoreTransaction?,
    hasPurchaseController: Bool,
    purchaseStartAt: Date
  ) -> Bool {
    if hasPurchaseController {
      return false
    }
    guard let transaction = transaction else {
      return false
    }

    // If has a transaction date and that happened before purchase
    // button was pressed...
    if let transactionDate = transaction.transactionDate,
      transactionDate < purchaseStartAt {
      // ...and if it has an expiration date that expires in the future,
      // then we must have restored.
      if let expirationDate = transaction.expirationDate {
        if expirationDate >= Date() {
          return true
        }
      } else {
        // If no expiration date, it must be a non-consumable product
        // which has been restored.
        return true
      }
    }

    return false
  }
}
