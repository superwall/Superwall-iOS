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

  /// Purchases products.
  ///
  /// If on iOS 15 and the dev hasn't disabled the finishing of transactions, the
  /// products are retrieved and purchased using StoreKit 2, otherwise using StoreKit 1.
  func purchase(product: StoreProduct) async -> InternalPurchaseResult {
    let purchaseStartAt = Date()
    let result = await storeKitManager.coordinator.productPurchaser.purchase(product: product)

    // TODO: Should this only be in debug? Maybe not at all?
    await storeKitManager.refreshReceipt()

    switch result {
    case .purchased:
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
