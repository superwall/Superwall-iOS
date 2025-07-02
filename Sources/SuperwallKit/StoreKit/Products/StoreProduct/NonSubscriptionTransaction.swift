//
//  NonSubscriptionTransaction.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/07/2025.
//

import Foundation

@objc(SWKNonSubscriptionTransaction)
@objcMembers
public final class NonSubscriptionTransaction: NSObject {
  /// The unique identifier for the transaction.
  public let transactionId: UInt64

  /// The product identifier of the in-app purchase.
  public let productId: String

  /// The date that the App Store charged the user’s account.
  public let purchaseDate: Date

  init(
    transactionId: UInt64,
    productId: String,
    purchaseDate: Date
  ) {
    self.transactionId = transactionId
    self.productId = productId
    self.purchaseDate = purchaseDate
  }
}
