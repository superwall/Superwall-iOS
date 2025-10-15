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
  /// A `Set` of the product identifiers for the active subscriptions.
  public var activeSubscriptionProductIds: Set<String> {
    return Set(
      subscriptions
        .filter { $0.isActive }
        .map((\.productId))
    )
  }

  /// A dictionary mapping product IDs to their associated entitlements.
  var entitlementsByProductId: [String: Set<Entitlement>] {
    var result: [String: Set<Entitlement>] = [:]
    for entitlement in entitlements {
      for productId in entitlement.productIds {
        result[productId, default: []].insert(entitlement)
      }
    }
    return result
  }

  /// The subscription transactions the user has made. The transactions are
  /// ordered by purchase date in ascending order.
  public let subscriptions: [SubscriptionTransaction]

  /// The non-subscription transactions the user has made. The transactions are
  /// ordered by purchase date in ascending order.
  public let nonSubscriptions: [NonSubscriptionTransaction]

  /// The ID of the user. Equivalent to ``Superwall/userId``.
  public var userId: String {
    if Superwall.isInitialized {
      return Superwall.shared.userId
    }
    return ""
  }

  /// All entitlements available to the user.
  public internal(set) var entitlements: [Entitlement]

  /// Internally set to `true` on first ever load of CustomerInfo`.
  let isBlank: Bool

  init(
    subscriptions: [SubscriptionTransaction],
    nonSubscriptions: [NonSubscriptionTransaction],
    entitlements: [Entitlement],
    isBlank: Bool = false
  ) {
    self.subscriptions = subscriptions
    self.nonSubscriptions = nonSubscriptions
    self.entitlements = entitlements
    self.isBlank = isBlank
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? CustomerInfo else {
      return false
    }

    return self.subscriptions == other.subscriptions &&
      self.nonSubscriptions == other.nonSubscriptions &&
      self.userId == other.userId &&
      self.entitlements == other.entitlements &&
      self.isBlank == other.isBlank
  }

  override public var hash: Int {
    var hasher = Hasher()
    hasher.combine(subscriptions)
    hasher.combine(nonSubscriptions)
    hasher.combine(userId)
    hasher.combine(entitlements)
    hasher.combine(isBlank)
    return hasher.finalize()
  }

  private enum CodingKeys: String, CodingKey {
    case subscriptions
    case nonSubscriptions
    case userId
    case entitlements
    case isBlank
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    subscriptions = try container.decode([SubscriptionTransaction].self, forKey: .subscriptions)
    nonSubscriptions = try container.decode([NonSubscriptionTransaction].self, forKey: .nonSubscriptions)
    entitlements = try container.decode([Entitlement].self, forKey: .entitlements)
    isBlank = try container.decodeIfPresent(Bool.self, forKey: .isBlank) ?? false
    super.init()
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(subscriptions, forKey: .subscriptions)
    try container.encode(nonSubscriptions, forKey: .nonSubscriptions)
    try container.encode(entitlements, forKey: .entitlements)
    try container.encode(isBlank, forKey: .isBlank)
  }

  static func blank() -> CustomerInfo {
    return CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [],
      isBlank: true
    )
  }

  /// Merges this CustomerInfo (device) with web CustomerInfo, deduplicating transactions by transaction ID.
  ///
  /// This method combines transaction history and entitlements from both on-device purchases
  /// and web-based purchases/redemptions. It ensures:
  /// - No duplicate transactions (keyed by `transactionId`)
  /// - Web entitlements take precedence over device entitlements when IDs match
  /// - All transactions are sorted by purchase date
  ///
  /// - Parameter webCustomerInfo: The CustomerInfo from web2app endpoints containing web purchases/redemptions
  /// - Returns: A new CustomerInfo with merged data from both sources
  func merging(with webCustomerInfo: CustomerInfo) -> CustomerInfo {
    // Merge non-subscription transactions (consumables, non-consumables)
    // Start with device transactions, then add web transactions that don't already exist
    var mergedNonSubscriptions = self.nonSubscriptions
    for webNonSub in webCustomerInfo.nonSubscriptions where !mergedNonSubscriptions.contains(
      where: { $0.transactionId == webNonSub.transactionId }
    ) {
      mergedNonSubscriptions.append(webNonSub)
    }

    // Merge subscription transactions
    // Start with device subscriptions, then add web subscriptions that don't already exist
    // This prevents showing duplicate subscription history when a user has both native and
    // web purchases
    var mergedSubscriptions = self.subscriptions
    for webSub in webCustomerInfo.subscriptions where !mergedSubscriptions.contains(
      where: { $0.transactionId == webSub.transactionId }
    ) {
      mergedSubscriptions.append(webSub)
    }

    // Merge entitlements using priority-based merging
    // This uses `Entitlement.mergePrioritized` which intelligently selects the highest
    // priority entitlement for each ID based on:
    // - Active status (active > inactive)
    // - Latest expiration date
    // - Other priority criteria defined in `shouldTakePriorityOver`
    let combinedEntitlements = self.entitlements + webCustomerInfo.entitlements
    let mergedEntitlements = Entitlement.mergePrioritized(combinedEntitlements)

    // Return merged CustomerInfo with sorted transactions and entitlements
    return CustomerInfo(
      subscriptions: mergedSubscriptions.sorted { $0.purchaseDate < $1.purchaseDate },
      nonSubscriptions: mergedNonSubscriptions.sorted { $0.purchaseDate < $1.purchaseDate },
      entitlements: mergedEntitlements.sorted { $0.id < $1.id }
    )
  }
}

extension CustomerInfo: Stubbable {
  static func stub() -> CustomerInfo {
    return blank()
  }
}
