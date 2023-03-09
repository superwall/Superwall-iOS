//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/10/2022.
//

import Foundation
import StoreKit

/// The Objective-C-only protocol that handles Superwall's subscription-related logic.
///
/// By default, the Superwall SDK handles all subscription-related logic. However, if you'd like
/// more control, you can return a ``PurchaseControllerObjc`` in the delegate when
/// configuring the SDK via
/// ``Superwall/configure(apiKey:purchaseController:options:completion:)-52tke``.
///
/// When implementing this, you also need to set the subscription status using
/// ``Superwall/subscriptionStatus``.
///
/// To learn how to implement the ``PurchaseControllerObjc`` in your app
/// and best practices, see <doc:AdvancedConfiguration>.
@objc(SWKPurchaseController)
public protocol PurchaseControllerObjc: AnyObject {
  /// Called when the user initiates purchasing of a product.
  ///
  /// Add your purchase logic here and call the completion block with the result. You can use Apple's StoreKit APIs,
  /// or if you use RevenueCat, you can call [`Purchases.shared.purchase(product:)`](https://revenuecat.github.io/purchases-ios-docs/4.13.4/documentation/revenuecat/purchases/purchase(product:completion:)).
  /// - Parameters:
  ///   - product: The `SKProduct` the user would like to purchase.
  ///   - completion: A completion block the accepts a ``PurchaseResult`` object and an optional `Error`.
  ///   Call this with the result of your purchase logic. When you pass a `.failed` result, make sure you also pass
  ///   the error.
  ///    **Note:** Make sure you handle all cases of ``PurchaseResult``.
  @MainActor
  @objc func purchase(
    product: SKProduct,
    completion: @escaping (PurchaseResultObjc, Error?) -> Void
  )

  /// Called when the user initiates a restore.
  ///
  /// Add your restore logic here, making sure that the user's subscription status is updated after restore,
  /// and return its result.
  /// 
  /// - Parameters:
  ///   - completion: Call the completion with `true` if the user's purchases were restored or `false` if they weren't.
  @MainActor
  @objc func restorePurchases(completion: @escaping (Bool) -> Void)
}
