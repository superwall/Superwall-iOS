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

  /// Purchases the product and then checks for a transaction,
  func purchase(product: StoreProduct) async -> InternalPurchaseResult {
    let purchaseStartAt = Date()

    let result = await storeKitManager.coordinator.productPurchaser.purchase(product: product)

    let transactionResult = await checkForTransaction(
      result,
      product: product,
      startAt: purchaseStartAt
    )

    switch result {
    case .failed(let error):
      return .failed(error)
    case .pending:
      return .pending
    case .cancelled:
      return .cancelled
    case .purchased:
      return transactionResult ?? .failed(PurchaseError.noTransactionDetected)
    }
  }

  /// Called to double check people aren't cheating the system.
  private func checkForTransaction(
    _ result: PurchaseResult,
    product: StoreProduct,
    startAt: Date
  ) async -> InternalPurchaseResult? {
    do {
      // If the product was reported purchased, we just check it's valid.
      // This is because someone may have reinstalled app and now gone to
      // purchase without restoring. In this case, it returns a purchased
      // product immediately whose date is in the past.
      //
      // If the product wasn't reported purchased by the dev, we still need
      // to check for transactions since a purchase request has been made.

      // TODO: What happens if it's pending and they do the flow above?
      let transaction = try await storeKitManager.coordinator.txnChecker.getAndValidateLatestTransaction(
        of: product.productIdentifier,
        since: result == .purchased ? nil : startAt,
        hasPurchaseController: hasPurchaseController
      )
      return .purchased(transaction)
    } catch {
      // If an error occured, it could be because they actually didn't
      // purchase. In which case we return nil.
      guard case .purchased = result else {
        return nil
      }
      if let error = error as? PurchaseError {
        return .failed(error)
      } else {
        return .failed(PurchaseError.unknown)
      }
    }
  }
}
