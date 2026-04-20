//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/09/2023.
//

import StoreKit

@available(iOS 15.0, *)
extension Transaction {
  /// Gets the latest transaction for a given `productId` since
  /// an hour up to a given `purchaseDate`.
  static func latest(
    for productId: String,
    since purchaseDate: Date
  ) async -> VerificationResult<Transaction>? {
    let verificationResult = await Transaction.latest(for: productId)

    if let transaction = verificationResult.map({ $0.unsafePayloadValue }),
      transaction.purchaseDate.isWithinAnHourBefore(purchaseDate) {
      return verificationResult
    }

    return nil
  }

  /// Gets the current entitlement transaction for a given `productId`
  /// whose purchase date is within an hour of the given `purchaseDate`.
  /// Uses `currentEntitlements(for:)` on iOS 18.4+ (which returns multiple
  /// transactions, e.g. direct + Family Sharing), falling back to the
  /// deprecated `currentEntitlement(for:)` on older versions.
  static func currentEntitlement(
    for productId: String,
    since purchaseDate: Date
  ) async -> VerificationResult<Transaction>? {
    #if compiler(>=6.1)
    if #available(iOS 18.4, visionOS 2.4, *) {
      var best: VerificationResult<Transaction>?

      for await result in Transaction.currentEntitlements(for: productId) {
        let transaction = result.unsafePayloadValue

        if !transaction.purchaseDate.isWithinAnHourBefore(purchaseDate) {
          continue
        }

        if let currentBest = best?.unsafePayloadValue,
          currentBest.purchaseDate >= transaction.purchaseDate {
          continue
        }

        best = result
      }

      return best
    }
    #endif

    let verificationResult = await Transaction.currentEntitlement(for: productId)

    if let transaction = verificationResult.map({ $0.unsafePayloadValue }),
      transaction.purchaseDate.isWithinAnHourBefore(purchaseDate) {
      return verificationResult
    }

    return nil
  }
}
