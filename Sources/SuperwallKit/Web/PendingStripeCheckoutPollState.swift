//
//  PendingStripeCheckoutPollState.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/02/2026.
//

import Foundation

struct PendingStripeCheckoutPollState: Codable, Equatable {
  static let defaultForegroundAttempts = 5
  /// How long a checkout known to be paid is kept after it was last tried: as long as a
  /// teleport is worth checking.
  static let paidTimeLimit: TimeInterval = PendingTeleportState.timeLimit

  let checkoutContextId: String
  let productId: String
  /// How the checkout finishes once its code is redeemed. A recovery poll (on foreground or
  /// paywall open) finishes it the way the paywall asked, not as a restore.
  let completion: StripeCheckoutCompletion
  /// Whether something said the checkout was paid for, such as a return link. One that was
  /// only submitted may never be paid, so it's given up on sooner.
  let isPaid: Bool
  let remainingForegroundAttempts: Int
  let updatedAt: Date

  init(
    checkoutContextId: String,
    productId: String,
    completion: StripeCheckoutCompletion = .restore,
    isPaid: Bool = false,
    remainingForegroundAttempts: Int = defaultForegroundAttempts,
    updatedAt: Date = Date()
  ) {
    self.checkoutContextId = checkoutContextId
    self.productId = productId
    self.completion = completion
    self.isPaid = isPaid
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
    isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
    remainingForegroundAttempts = try container.decode(Int.self, forKey: .remainingForegroundAttempts)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  func consumingForegroundAttempt() -> PendingStripeCheckoutPollState {
    PendingStripeCheckoutPollState(
      checkoutContextId: checkoutContextId,
      productId: productId,
      completion: completion,
      isPaid: isPaid,
      remainingForegroundAttempts: max(remainingForegroundAttempts - 1, 0),
      updatedAt: Date()
    )
  }
}
