//
//  CustomerInfo.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 02/07/2025.
//

import Foundation

/// A class that contains the latest subscription and entitlement info about the customer.
/// These objects are non-mutable and do not update automatically.
@objc(SWKCustomerInfo)
@objcMembers
public final class CustomerInfo: NSObject, Codable {
  /// The subscription transactions the user has made. The transactions are
  /// ordered by purchase date in ascending order.
  public let subscriptions: [SubscriptionTransaction]

  /// The non-subscription transactions the user has made. The transactions are
  /// ordered by purchase date in ascending order.
  public let nonSubscriptions: [NonSubscriptionTransaction]

  /// The ID of the user. Equivalent to ``Superwall/userId``.
  public let userId: String

  /// All entitlements available to the user.
  public let entitlements: [Entitlement]

  init(
    subscriptions: [SubscriptionTransaction],
    nonSubscriptions: [NonSubscriptionTransaction],
    userId: String,
    entitlements: [Entitlement]
  ) {
    self.subscriptions = subscriptions
    self.nonSubscriptions = nonSubscriptions
    self.userId = userId
    self.entitlements = entitlements
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? CustomerInfo else {
      return false
    }

    return self.subscriptions == other.subscriptions &&
      self.nonSubscriptions == other.nonSubscriptions &&
      self.userId == other.userId &&
      self.entitlements == other.entitlements
  }

  override public var hash: Int {
    var hasher = Hasher()
    hasher.combine(subscriptions)
    hasher.combine(nonSubscriptions)
    hasher.combine(userId)
    hasher.combine(entitlements)
    return hasher.finalize()
  }

  private enum CodingKeys: String, CodingKey {
    case subscriptions
    case nonSubscriptions
    case userId
    case entitlements
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    subscriptions = try container.decode([SubscriptionTransaction].self, forKey: .subscriptions)
    nonSubscriptions = try container.decode([NonSubscriptionTransaction].self, forKey: .nonSubscriptions)
    userId = try container.decode(String.self, forKey: .userId)
    entitlements = try container.decode([Entitlement].self, forKey: .entitlements)
    super.init()
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(subscriptions, forKey: .subscriptions)
    try container.encode(nonSubscriptions, forKey: .nonSubscriptions)
    try container.encode(userId, forKey: .userId)
    try container.encode(entitlements, forKey: .entitlements)
  }
}
