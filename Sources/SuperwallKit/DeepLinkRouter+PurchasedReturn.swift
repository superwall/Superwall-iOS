//
//  DeepLinkRouter+PurchasedReturn.swift
//  SuperwallKit
//
//  Created by Christo Todorov on 19/11/2026.
//

import Foundation

/// A checkout that a return link says the user paid for.
struct PurchasedReturn: Equatable {
  let checkoutContextId: String
  let productId: String
  let completion: StripeCheckoutCompletion
}

extension URL {
  /// The checkout a return link says was paid for: `reason=purchased` with the checkout's
  /// `checkout_context_id`, and optionally the `product_identifier` bought and whether the
  /// paywall dismisses after it (`should_dismiss`). Nil for any other return link, or one
  /// without a checkout context id.
  var superwallPurchasedReturn: PurchasedReturn? {
    guard
      isSuperwallReturnLink,
      superwallReturnReason == "purchased"
    else {
      return nil
    }
    let items = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? {
      guard let value = items.first(where: { $0.name == name })?.value, !value.isEmpty else {
        return nil
      }
      return value
    }
    guard let checkoutContextId = value("checkout_context_id") else {
      return nil
    }
    let productId = value("product_identifier") ?? ""
    let shouldDismiss: Bool? = value("should_dismiss").flatMap {
      switch $0.lowercased() {
      case "true", "1":
        return true
      case "false", "0":
        return false
      default:
        return nil
      }
    }
    // As with `stripe_checkout_complete`: a link that says whether to dismiss finishes the
    // purchase like an App Store purchase, one that doesn't gets the legacy restore.
    let completion: StripeCheckoutCompletion = shouldDismiss.map {
      .purchase(productId: productId, shouldDismiss: $0)
    } ?? .restore
    return PurchasedReturn(
      checkoutContextId: checkoutContextId,
      productId: productId,
      completion: completion
    )
  }
}
