//
//  CustomStoreCheckout.swift
//  SuperwallKit
//
//  Created by Superwall on 21/10/2026.
//

/// A step of a custom store checkout that the paywall runs itself.
///
/// When a custom store has a checkout endpoint, the paywall gets a checkout
/// URL from Superwall, opens it and polls for its outcome, then tells the SDK
/// about each step. The SDK finishes the purchase as it would one returned by a
/// `PurchaseController`, without calling the `PurchaseController`.
enum CustomStoreCheckout: Equatable {
  /// The paywall opened the checkout. `customTransactionId` is the id Superwall
  /// generated for it and passed to the developer's checkout endpoint.
  case start(productId: String, customTransactionId: String)

  /// The buyer completed the checkout.
  case complete(productId: String, customTransactionId: String, shouldDismiss: Bool)

  /// The buyer backed out of the checkout.
  case abandon(productId: String)

  /// The checkout couldn't be created or opened.
  case fail(productId: String, message: String)

  /// The `Product.id` the paywall is selling.
  var productId: String {
    switch self {
    case .start(let productId, _),
      .complete(let productId, _, _),
      .abandon(let productId),
      .fail(let productId, _):
      return productId
    }
  }
}
