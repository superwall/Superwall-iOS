//
//  PendingTeleportState.swift
//  SuperwallKit
//
//  Created by Christo Todorov on 19/11/2026.
//

import Foundation

/// A teleport the paywall opened in Safari, kept so it can be finished if iOS ends the app before
/// the paywall page hears how it went.
struct PendingTeleportState: Codable, Equatable {
  /// How long a teleport is worth checking: the paywall page waits as long for a teleport whose
  /// checkout was started (twice the teleport's 30 minutes) before it gives up on it.
  static let timeLimit: TimeInterval = 60 * 60

  let teleportId: String
  /// The product the paywall sent the user to buy. Empty when the page didn't say.
  let productId: String
  /// Whether the paywall dismisses after the purchase. Nil when the page didn't say, in which
  /// case the purchase finishes as a restore, as a `stripe_checkout_complete` without it does.
  let shouldDismiss: Bool?
  let openedAt: Date

  init(
    teleportId: String,
    productId: String,
    shouldDismiss: Bool? = nil,
    openedAt: Date = Date()
  ) {
    self.teleportId = teleportId
    self.productId = productId
    self.shouldDismiss = shouldDismiss
    self.openedAt = openedAt
  }

  func hasExpired(at date: Date = Date()) -> Bool {
    date.timeIntervalSince(openedAt) >= Self.timeLimit
  }

  /// The purchase to finish once the teleport reads completed, for the checkout it led to.
  func purchase(checkoutContextId: String, productId checkoutProductId: String?) -> PurchasedReturn {
    let productId = checkoutProductId.flatMap { $0.isEmpty ? nil : $0 } ?? self.productId
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

struct TeleportStatusRequest: Encodable {
  let teleportId: String
}

/// What the subscriptions API says about a teleport.
struct TeleportStatusResponse: Decodable, Equatable {
  /// `pending`, `claimed` (a checkout was started), `completed` (paid) or `expired`.
  let status: String
  /// The paid checkout once `completed`, or the checkout the teleport started.
  let checkoutContextId: String?
  /// The product that checkout sells, which may differ from the one the paywall offered.
  let checkoutProductIdentifier: String?

  var isCompleted: Bool {
    status == "completed"
  }

  /// A checkout was started but the teleport isn't marked paid yet. The backend marks it paid
  /// once the checkout page reports back, which can come seconds after the payment itself.
  var isClaimed: Bool {
    status == "claimed"
  }
}

struct CheckoutStatusRequest: Encodable {
  let checkoutId: String
}

/// What the subscriptions API says about a checkout, confirmed with the store.
struct CheckoutStatusResponse: Decodable, Equatable {
  /// `pending`, `completed` (paid) or `abandoned`.
  let status: String

  var isCompleted: Bool {
    status == "completed"
  }
}
