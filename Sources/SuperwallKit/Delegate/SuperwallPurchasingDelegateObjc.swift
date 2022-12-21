//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/10/2022.
//

import Foundation
import StoreKit

@MainActor
@objc(SWKSuperwallPurchasingDelegate)
public protocol SuperwallPurchasingDelegateObjc: AnyObject {
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
  @objc func purchase(
    product: SKProduct,
    completion: @escaping (PurchaseResultObjc, Error?) -> Void
  )

  /// Called when the user initiates a restore.
  ///
  /// Add your restore logic here.
  ///
  /// - Parameters:
  ///   - completion: Call the completion with `true` if the user's purchases were restored or `false` if they weren't.
  @objc func restorePurchases(completion: @escaping (Bool) -> Void)

  /// Decides whether a paywall should be presented based on whether the user is subscribed to any
  /// entitlements.
  ///
  /// Entitlements are subscription levels that products belong to, which you may have set up on the
  /// Superwall dashboard. For example, you may have "bronze", "silver" and "gold" entitlement levels
  /// within your app.
  ///
  /// You need to determine whether a user has a subscription to any of the of the entitlements in the
  /// `entitlements` parameter.
  ///
  /// If you're using RevenueCat, these entitlements should match the entitlements set in RevenueCat.
  ///
  /// If you do not use entitlements within your app, just return whether the user has any active
  /// subscription.
  ///
  /// - Warning: A paywall will never show if this function returns `true`.
  ///
  /// - Parameters:
  ///   - entitlements: An array of entitlements that your products belong to on the Superwall
  ///   dashboard. This may or may not be empty, depending on whether you've added products to
  ///   an entitlement.
  /// - Returns: A boolean that indicates whether or not the user has an active subscription.
  @objc func isUserSubscribed(toEntitlements entitlements: Set<String>) -> Bool
}
