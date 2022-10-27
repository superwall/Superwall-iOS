//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import StoreKit

final class ReceiptManager {
  var purchasedSubscriptionGroupIds: Set<String>?
  private var purchases: [InAppPurchase] = []
  private let productsManager: ProductsManager
  private let receiptData: () -> Data?

  init(
    productsManager: ProductsManager = .shared,
    receiptData: @escaping () -> Data? = ReceiptLogic.getReceiptData
  ) {
    self.productsManager = productsManager
    self.receiptData = receiptData
  }

  /// Gets the purchased products, whilst storing the purchased subscription group identifiers.
  func loadPurchasedProducts() async -> Set<SKProduct>? {
    guard let payload = ReceiptLogic.getPayload(using: receiptData) else {
      return nil
    }
    let purchases = payload.purchases
    let purchasedProductIds = Set(purchases.map { $0.productIdentifier })

    do {
      let products = try await productsManager.getProducts(identifiers: purchasedProductIds)

      var purchasedSubscriptionGroupIds: Set<String> = []
      for product in products {
        if let subscriptionGroupIdentifier = product.subscriptionGroupIdentifier {
          purchasedSubscriptionGroupIds.insert(subscriptionGroupIdentifier)
        }
      }
      self.purchasedSubscriptionGroupIds = purchasedSubscriptionGroupIds
      return products
    } catch {
      return nil
    }
  }

  /// Determines whether a free trial is available based on the product the user is purchasing.
  ///
  /// A free trial is available if the user hasn't already purchased within the subscription group of the
  /// supplied product. If it isn't a subscription-based product or there are other issues retrieving the products,
  /// the outcome will default to whether or not the user has already purchased that product.
  func isFreeTrialAvailable(for product: SKProduct) -> Bool {
    guard product.hasFreeTrial else {
      return false
    }
    guard
      let purchasedSubsGroupIds = purchasedSubscriptionGroupIds,
      let subsGroupId = product.subscriptionGroupIdentifier
    else {
      return !hasPurchasedProduct(withId: product.productIdentifier)
    }

    return !purchasedSubsGroupIds.contains(subsGroupId)
  }

  /// Determines whether the purchases already contain the given product ID.
  func hasPurchasedProduct(withId productId: String) -> Bool {
    return purchases.first { $0.productIdentifier == productId } != nil
  }
}
