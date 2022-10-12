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

  init(productsManager: ProductsManager = ProductsManager()) {
    self.productsManager = productsManager
  }

  /// Gets the purchased products, whilst storing the purchased subscription group identifiers.
  func loadPurchasedProducts() async -> Set<SKProduct>? {
    guard let payload = ReceiptLogic.getPayload() else {
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

  /// Determines whether the purchases already contain the given product ID.
  func hasPurchasedProduct(withId productId: String) -> Bool {
    return purchases.first { $0.productIdentifier == productId } != nil
  }
}
