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
      // TODO: Write somewhere that the app's subscription status is device specific
      // TODO: Mention that the free trial may still show in sandbox after a user makes a free trial (but doesnt purchase) because receipt only present after a purchase: https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/validating_receipts_with_the_app_store
      // TODO: Should this: only be in debug? Maybe not at all? Should it be in pending too? Think RC actually always refresh, not clear why.
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
