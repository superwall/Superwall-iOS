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

  func purchase(product: StoreProduct) async -> InternalPurchaseResult {
    let purchaseStartAt = Date()
    let result = await storeKitManager.coordinator.productPurchaser.purchase(product: product)

    switch result {
    case .purchased:
      /// Always refreshing. Not sure this is 100% necessary but this is what RC do...
      await storeKitManager.refreshReceipt()
      do {
        let transaction = try await storeKitManager.coordinator.txnChecker.getAndValidateTransaction(
          of: product.productIdentifier,
          since: purchaseStartAt
        )
        return .purchased(transaction)
      } catch let error as PurchaseError {
        return .failed(error)
      } catch {
        return .failed(PurchaseError.unknown)
      }
    case .failed(let error):
      return .failed(error)
    case .pending:
      return .pending
    case .cancelled:
      return .cancelled
    }
  }
}
