//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/09/2024.
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
final class ProductPurchaserSK2: Purchasing {
  private unowned let identityManager: IdentityManager
  private unowned let receiptManager: ReceiptManager
  private unowned let factory: HasExternalPurchaseControllerFactory

  init(
    identityManager: IdentityManager,
    receiptManager: ReceiptManager,
    factory: HasExternalPurchaseControllerFactory
  ) {
    self.identityManager = identityManager
    self.receiptManager = receiptManager
    self.factory = factory
  }

  func purchase(product: StoreProduct) async -> PurchaseResult {
    guard let product = product.sk2Product else {
      return .cancelled
    }
    do {
      var options: Set<StoreKit.Product.PurchaseOption> = []
      if let appUserId = identityManager.appUserId,
        let uuid = UUID(uuidString: appUserId) {
        options.insert(.appAccountToken(uuid))
      }

      let purchaseDate = Date()

      let result = try await product.purchase()

      switch result {
      case let .success(.verified(transaction)):
        await transaction.finish()
        await receiptManager.loadPurchasedProducts()

        let transactionDate = transaction.purchaseDate
        if transactionDate < purchaseDate {
          return .restored
        }
        return .purchased
      case let .success(.unverified(transaction, error)):
        await transaction.finish()
        return .failed(error)
      case .userCancelled:
        return .cancelled
      case .pending:
        return .pending
      @unknown default:
        return .cancelled
      }
    } catch let error as StoreKitError {
      switch error {
      case .userCancelled:
        return .cancelled
      default:
        return .failed(error)
      }
    } catch {
      return .failed(error)
    }
  }

  func restorePurchases() async -> RestorationResult {
    var hasRestored = false
    var error: Error?

    for await verificationResult in StoreKit.Transaction.all {
      switch verificationResult {
      case .verified:
        hasRestored = true
      case .unverified(_, let transactionError):
        error = transactionError
      }
    }

    if hasRestored {
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Restore Completed Transactions Finished"
      )
      return .restored
    } else {
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Restore Completed Transactions Failed With Error",
        error: error
      )
      return .failed(error)
    }
  }
}
