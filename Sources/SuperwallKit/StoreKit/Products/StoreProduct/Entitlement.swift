//
//  File.swift
//
//
//  Created by Yusuf Tör on 06/08/2024.
//

import Foundation

/// An enum whose types specify the store which the product belongs to.
@objc(SWKEntitlementType)
public enum EntitlementType: Int, Codable, Sendable {
  /// An Apple App Store product.
  case serviceLevel

  private enum CodingKeys: String, CodingKey {
    case serviceLevel = "SERVICE_LEVEL"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let type = CodingKeys(rawValue: rawValue)
    switch type {
    case .serviceLevel:
      self = .serviceLevel
    case .none:
      throw DecodingError.valueNotFound(
        String.self,
        .init(
          codingPath: [],
          debugDescription: "Unsupported entitlement type."
        )
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .serviceLevel:
      try container.encode(CodingKeys.serviceLevel.rawValue)
    }
  }
}

/// An entitlement that represents a subscription tier in your app.
@objc(SWKEntitlement)
@objcMembers
public final class Entitlement: NSObject, Codable, Sendable {
  /// The identifier for the entitlement.
  public let id: String

  /// The type of entitlement.
  public let type: EntitlementType

  // MARK: - Added on device after retrieving from server.
  /// Indicates whether there is any active, non-revoked, transaction for this entitlement.
  public let isActive: Bool

  /// All product identifiers that map to the entitlement.
  public let productIds: Set<String>

  /// The product identifer of the latest transaction to unlock this entitlement.
  ///
  /// If one or more lifetime products unlock this entitlement, the `latestProductId` will always be the product identifier of the first lifetime product.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  public let latestProductId: String?

  /// The purchase date of the first transaction that unlocked this entitlement.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  public let startsAt: Date?

  /// The date that the entitlement was last renewed.
  ///
  /// This could be `nil` if:
  ///   - There aren't any transactions that unlock this entitlement.
  ///   - It was the first purchase.
  ///   - If the entitlement belongs to a non-renewing subscription or non-consumable product.
  public let renewedAt: Date?

  /// The expiry date of the last transaction that unlocked this entitlement.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement or
  /// if a lifetime product unlocked this entitlement.
  public let expiresAt: Date?

  /// Indicates whether the entitlement is active for a lifetime due to the purchase of a non-consumable.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  public let isLifetime: Bool?

  /// Indicates whether the last subscription transaction associated with this
  /// entitlement was revoked.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  public var isRevoked: Bool? {
    guard let state = state else {
      return nil
    }
    return state == .revoked
  }

  /// Indicates whether the last subscription transaction associated with this entitlement will auto renew.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  public let willRenew: Bool?

  /// The `Date` at which the subscription renews, if at all.
  ///
  /// This is `nil` if it won't renew or isn't active.
  public var renewsAt: Date? {
    guard isActive else {
      return nil
    }
    guard willRenew == true else {
      return nil
    }
    return expiresAt
  }

  /// Indicates whether the last subscription transaction associated with this
  /// entitlement is in a billing grace period state.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  public var isInGracePeriod: Bool? {
    guard let state = state else {
      return nil
    }
    return state == .inGracePeriod
  }

  /// The state of the last subscription transaction associated with the
  /// entitlement.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  public let state: LatestSubscription.State?

  /// The type of offer that applies to the last subscription transaction that
  /// unlocks this entitlement.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  ///
  /// - Note: This is only non-`nil` on iOS 17.2+.
  public let offerType: LatestSubscription.OfferType?

  private enum CodingKeys: String, CodingKey {
    case id = "identifier"
    case type

    case isActive
    case productIds
    case latestProductId
    case startsAt
    case renewedAt
    case expiresAt
    case isLifetime
    case willRenew
    case state
    case offerType
  }

  init(
    id: String,
    type: EntitlementType = .serviceLevel,
    isActive: Bool = false,
    productIds: Set<String> = [],
    latestProductId: String? = nil,
    startsAt: Date? = nil,
    renewedAt: Date? = nil,
    expiresAt: Date? = nil,
    isLifetime: Bool? = nil,
    willRenew: Bool? = nil,
    state: LatestSubscription.State? = nil,
    offerType: LatestSubscription.OfferType? = nil
  ) {
    self.id = id
    self.type = type
    self.isActive = isActive
    self.productIds = productIds
    self.latestProductId = latestProductId
    self.startsAt = startsAt
    self.renewedAt = renewedAt
    self.expiresAt = expiresAt
    self.isLifetime = isLifetime
    self.willRenew = willRenew
    self.state = state
    self.offerType = offerType
  }

  public convenience init(
    id: String
  ) {
    self.init(id: id, type: .serviceLevel)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.type = try container.decode(EntitlementType.self, forKey: .type)
    self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    self.productIds = try container.decodeIfPresent(Set<String>.self, forKey: .productIds) ?? []
    self.latestProductId = try container.decodeIfPresent(String.self, forKey: .latestProductId)
    self.startsAt = try container.decodeIfPresent(Date.self, forKey: .startsAt)
    self.renewedAt = try container.decodeIfPresent(Date.self, forKey: .renewedAt)
    self.expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
    self.isLifetime = try container.decodeIfPresent(Bool.self, forKey: .isLifetime)
    self.willRenew = try container.decodeIfPresent(Bool.self, forKey: .willRenew)
    self.state = try container.decodeIfPresent(LatestSubscription.State.self, forKey: .state)
    self.offerType = try container.decodeIfPresent(LatestSubscription.OfferType.self, forKey: .offerType)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(type, forKey: .type)
    try container.encodeIfPresent(isActive, forKey: .isActive)
    try container.encodeIfPresent(productIds, forKey: .productIds)
    try container.encodeIfPresent(latestProductId, forKey: .latestProductId)
    try container.encodeIfPresent(startsAt, forKey: .startsAt)
    try container.encodeIfPresent(renewedAt, forKey: .renewedAt)
    try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
    try container.encodeIfPresent(isLifetime, forKey: .isLifetime)
    try container.encodeIfPresent(willRenew, forKey: .willRenew)
    try container.encodeIfPresent(state, forKey: .state)
    try container.encodeIfPresent(offerType, forKey: .offerType)
  }

  // Override isEqual to define equality based on `id` and `type`
  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? Entitlement else {
      return false
    }
    return self.id == other.id
      && self.type == other.type
      && self.isActive == other.isActive
      && self.productIds == other.productIds
      && self.latestProductId == other.latestProductId
      && self.startsAt == other.startsAt
      && self.renewedAt == other.renewedAt
      && self.expiresAt == other.expiresAt
      && self.isLifetime == other.isLifetime
      && self.willRenew == other.willRenew
      && self.willRenew == other.willRenew
      && self.state == other.state
      && self.offerType == other.offerType
  }

  public override var hash: Int {
    var hasher = Hasher()
    hasher.combine(id)
    hasher.combine(type)
    hasher.combine(isActive)
    hasher.combine(productIds)
    hasher.combine(latestProductId)
    hasher.combine(startsAt)
    hasher.combine(renewedAt)
    hasher.combine(expiresAt)
    hasher.combine(isLifetime)
    hasher.combine(willRenew)
    hasher.combine(state)
    hasher.combine(offerType)
    return hasher.finalize()
  }
}

// MARK: - Stubbable
extension Entitlement: Stubbable {
  static func stub() -> Entitlement {
    return Entitlement(
      id: "test",
      type: .serviceLevel
    )
  }
}
