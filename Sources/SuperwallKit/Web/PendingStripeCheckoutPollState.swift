//
//  PendingStripeCheckoutPollState.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/02/2026.
//

import Foundation

struct PendingStripeCheckoutPollState: Codable, Equatable {
  static let defaultForegroundAttempts = 5

  let checkoutContextId: String
  let productId: String
  /// How the checkout finishes once its code is redeemed. A recovery poll (on foreground or
  /// paywall open) finishes it the way the paywall asked, not as a restore.
  let completion: StripeCheckoutCompletion
  let remainingForegroundAttempts: Int
  let updatedAt: Date

  init(
    checkoutContextId: String,
    productId: String,
    completion: StripeCheckoutCompletion = .restore,
    remainingForegroundAttempts: Int = defaultForegroundAttempts,
    updatedAt: Date = Date()
  ) {
    self.checkoutContextId = checkoutContextId
    self.productId = productId
    self.completion = completion
    self.remainingForegroundAttempts = remainingForegroundAttempts
    self.updatedAt = updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    checkoutContextId = try container.decode(String.self, forKey: .checkoutContextId)
    productId = try container.decode(String.self, forKey: .productId)
    // State saved by an SDK before the completion was stored finishes as a restore, as it did then.
    completion = try container.decodeIfPresent(
      StripeCheckoutCompletion.self,
      forKey: .completion
    ) ?? .restore
    remainingForegroundAttempts = try container.decode(Int.self, forKey: .remainingForegroundAttempts)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  func consumingForegroundAttempt() -> PendingStripeCheckoutPollState {
    PendingStripeCheckoutPollState(
      checkoutContextId: checkoutContextId,
      productId: productId,
      completion: completion,
      remainingForegroundAttempts: max(remainingForegroundAttempts - 1, 0),
      updatedAt: Date()
    )
  }
}
