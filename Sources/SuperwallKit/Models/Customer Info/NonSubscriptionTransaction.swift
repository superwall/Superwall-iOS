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
  public let transactionId: String

  /// The product identifier of the in-app purchase.
  public let productId: String

  /// The date that the App Store charged the user’s account.
  public let purchaseDate: Date

  /// Indicates whether it's a consumable in-app purchase.
  public let isConsumable: Bool

  /// Indicates whether the transaction has been revoked.
  public let isRevoked: Bool

  init(
    transactionId: String,
    productId: String,
    purchaseDate: Date,
    isConsumable: Bool,
    isRevoked: Bool
  ) {
    self.transactionId = transactionId
    self.productId = productId
    self.purchaseDate = purchaseDate
    self.isConsumable = isConsumable
    self.isRevoked = isRevoked
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? NonSubscriptionTransaction else {
      return false
    }
    return self.transactionId == other.transactionId &&
      self.productId == other.productId &&
      self.purchaseDate == other.purchaseDate &&
      self.isConsumable == other.isConsumable &&
      self.isRevoked == other.isRevoked
  }

  override public var hash: Int {
    var hasher = Hasher()
    hasher.combine(transactionId)
    hasher.combine(productId)
    hasher.combine(purchaseDate)
    hasher.combine(isConsumable)
    hasher.combine(isRevoked)
    return hasher.finalize()
  }

  private enum CodingKeys: String, CodingKey {
    case transactionId
    case productId
    case purchaseDate
    case isConsumable
    case isRevoked
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    transactionId = try container.decode(String.self, forKey: .transactionId)
    productId = try container.decode(String.self, forKey: .productId)
    purchaseDate = try container.decode(Date.self, forKey: .purchaseDate)
    isConsumable = try container.decode(Bool.self, forKey: .isConsumable)
    isRevoked = try container.decode(Bool.self, forKey: .isRevoked)
    super.init()
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(transactionId, forKey: .transactionId)
    try container.encode(productId, forKey: .productId)
    try container.encode(purchaseDate, forKey: .purchaseDate)
    try container.encode(isConsumable, forKey: .isConsumable)
    try container.encode(isRevoked, forKey: .isRevoked)
  }
}
