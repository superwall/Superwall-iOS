//
//  NonSubscriptionTransaction.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/07/2025.
//

import Foundation

@objc(SWKNonSubscriptionTransaction)
@objcMembers
public final class NonSubscriptionTransaction: NSObject, Codable {
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

  override public func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? NonSubscriptionTransaction else {
      return false
    }
    return self.transactionId == other.transactionId &&
      self.productId == other.productId &&
      self.purchaseDate == other.purchaseDate
  }

  override public var hash: Int {
    var hasher = Hasher()
    hasher.combine(transactionId)
    hasher.combine(productId)
    hasher.combine(purchaseDate)
    return hasher.finalize()
  }

  private enum CodingKeys: String, CodingKey {
    case transactionId, productId, purchaseDate
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    transactionId = try container.decode(UInt64.self, forKey: .transactionId)
    productId = try container.decode(String.self, forKey: .productId)
    purchaseDate = try container.decode(Date.self, forKey: .purchaseDate)
    super.init()
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(transactionId, forKey: .transactionId)
    try container.encode(productId, forKey: .productId)
    try container.encode(purchaseDate, forKey: .purchaseDate)
  }
}
