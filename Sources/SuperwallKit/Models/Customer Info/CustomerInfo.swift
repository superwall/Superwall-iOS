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
  /// All subscription product identifiers with expiration dates in the future.
  public let activeSubscriptions: Set<String>

  /// The non-subscription transactions the user has made. The purchases are
  /// ordered by purchase date in ascending order.
  public let nonSubscriptions: [NonSubscriptionTransaction]

  /// The ID of the user. Equivalent to ``Superwall/userId``.
  public let userId: String

  /// All entitlements available to the user.
  public let entitlements: [Entitlement]

  init(
    activeSubscriptions: Set<String>,
    nonSubscriptions: [NonSubscriptionTransaction],
    userId: String,
    entitlements: [Entitlement]
  ) {
    self.activeSubscriptions = activeSubscriptions
    self.nonSubscriptions = nonSubscriptions
    self.userId = userId
    self.entitlements = entitlements
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? CustomerInfo else {
      return false
    }

    return self.activeSubscriptions == other.activeSubscriptions &&
      self.nonSubscriptions == other.nonSubscriptions &&
      self.userId == other.userId &&
      self.entitlements == other.entitlements
  }

  override public var hash: Int {
    var hasher = Hasher()
    hasher.combine(activeSubscriptions)
    hasher.combine(nonSubscriptions)
    hasher.combine(userId)
    hasher.combine(entitlements)
    return hasher.finalize()
  }

  // 1. Define your coding keys
  private enum CodingKeys: String, CodingKey {
    case activeSubscriptions
    case nonSubscriptions
    case userId
    case entitlements
  }

  // 2. Decoder initializer
  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    activeSubscriptions = try container.decode(Set<String>.self, forKey: .activeSubscriptions)
    nonSubscriptions = try container.decode([NonSubscriptionTransaction].self, forKey: .nonSubscriptions)
    userId = try container.decode(String.self, forKey: .userId)
    entitlements = try container.decode([Entitlement].self, forKey: .entitlements)
    super.init()
  }

  // 3. Encoder method
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(activeSubscriptions, forKey: .activeSubscriptions)
    try container.encode(nonSubscriptions, forKey: .nonSubscriptions)
    try container.encode(userId, forKey: .userId)
    try container.encode(entitlements, forKey: .entitlements)
  }
}
