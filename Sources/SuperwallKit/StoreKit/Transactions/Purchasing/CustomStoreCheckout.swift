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

  /// The checkout ended without a purchase, for `reason`.
  case abandon(productId: String, reason: AbandonReason = .buyer)

  /// The checkout couldn't be created or opened.
  case fail(productId: String, message: String)

  /// Why the paywall ended a checkout without a purchase.
  enum AbandonReason: String, Equatable {
    /// The buyer backed out of the checkout.
    case buyer
    /// The paywall closed while the checkout was open.
    case paywallClosed = "paywall_closed"
    /// The checkout didn't finish in time. The buyer may still be paying.
    case timeout

    /// Whether the buyer chose to end the checkout, so `transaction_abandon` may present
    /// a paywall. Otherwise one would appear after the buyer closed theirs, or over the
    /// checkout they're still paying in.
    var isBuyersChoice: Bool {
      return self == .buyer
    }
  }

  /// Whether handling the step closes the checkout's in-app browser. One that timed out
  /// stays open, since the buyer may still be paying in it.
  var closesBrowser: Bool {
    if case .abandon(_, .timeout) = self {
      return false
    }
    return true
  }

  /// The `Product.id` the paywall is selling.
  var productId: String {
    switch self {
    case .start(let productId, _),
      .complete(let productId, _, _),
      .abandon(let productId, _),
      .fail(let productId, _):
      return productId
    }
  }
}
