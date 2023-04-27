//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/01/2023.
//

import Foundation

protocol TransactionChecker: AnyObject {
  /// Gets and validates a transaction of a product, if the user isn't using
  /// a ``PurchaseController``.
  func getAndValidateLatestTransaction(
    of productId: String,
    since purchasedAt: Date?,
    hasPurchaseController: Bool
  ) async throws -> StoreTransaction?
}

protocol ProductPurchaser: AnyObject {
  /// Purchases a product and returns its result.
  func purchase(product: StoreProduct) async -> PurchaseResult
}

protocol ProductsFetcher: AnyObject {
  /// Fetches a set of products from their identifiers.
  func products(
    identifiers: Set<String>,
    forPaywall paywallName: String?
  ) async throws -> Set<StoreProduct>
}

protocol TransactionRestorer: AnyObject {
  /// Restores purchases.
  ///
  /// - Returns: A boolean indicating whether the restore request succeeded or failed.
  /// This doesn't mean that the user is now subscribed, just that there were no errors
  /// obtaining the restored transactions
  func restorePurchases() async -> RestorationResult
}
