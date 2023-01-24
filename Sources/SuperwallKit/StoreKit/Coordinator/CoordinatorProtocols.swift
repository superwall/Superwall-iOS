//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/01/2023.
//

import Foundation

protocol TransactionChecker: AnyObject {
  /// Gets and validates a transaction of a product.
  func getAndValidateLatestTransaction(
    of productId: String,
    since purchasedAt: Date?
  ) async throws -> StoreTransaction
}

protocol ProductPurchaser: AnyObject {
  /// Purchases a product and returns its result.
  func purchase(product: StoreProduct) async -> PurchaseResult
}

protocol ProductsFetcher: AnyObject {
  /// Fetches a set of products from their identifiers.
  func products(identifiers: Set<String>) async throws -> Set<StoreProduct>
}

protocol TransactionRestorer: AnyObject {
  /// Restores purchases.
  ///
  /// - Returns: A boolean indicating whether the restore request succeeded or failed.
  /// This doesn't mean that the user is now subscribed, just that there were no errors
  /// obtaining the restored transactions
  func restorePurchases() async -> Bool
}

protocol SubscriptionStatusChecker: AnyObject {
  /// Determines the subscription status of the user.
  func isSubscribed() -> Bool
}
