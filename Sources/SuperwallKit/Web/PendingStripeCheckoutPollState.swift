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
  let remainingForegroundAttempts: Int
  let updatedAt: Date

  init(
    checkoutContextId: String,
    productId: String,
    remainingForegroundAttempts: Int = defaultForegroundAttempts,
    updatedAt: Date = Date()
  ) {
    self.checkoutContextId = checkoutContextId
    self.productId = productId
    self.remainingForegroundAttempts = remainingForegroundAttempts
    self.updatedAt = updatedAt
  }

  func consumingForegroundAttempt() -> PendingStripeCheckoutPollState {
    PendingStripeCheckoutPollState(
      checkoutContextId: checkoutContextId,
      productId: productId,
      remainingForegroundAttempts: max(remainingForegroundAttempts - 1, 0),
      updatedAt: Date()
    )
  }
}
