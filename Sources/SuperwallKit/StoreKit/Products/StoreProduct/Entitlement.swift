//
//  File.swift
//
//
//  Created by Yusuf Tör on 06/08/2024.
//
// swiftlint:disable file_length cyclomatic_complexity

import Foundation

/// Type alias for ProductStore when used in the context of entitlements.
public typealias EntitlementStore = ProductStore

/// An enum whose types specify the entitlement tier type.
@objc(SWKEntitlementType)
public enum EntitlementType: Int, Codable, Sendable {
  /// A service level entitlement.
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
  /// This is `nil` if there aren't any transactions that unlock this entitlement or if it was manually granted from Superwall.
  public let latestProductId: String?

  /// The store from which this entitlement was granted.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement.
  public let store: EntitlementStore?

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
  /// This is `nil` if there aren't any transactions that unlock this entitlement or if it was manually granted from Superwall.
  public var isRevoked: Bool? {
    guard let state = state else {
      return nil
    }
    return state == .revoked
  }

  /// Indicates whether the last subscription transaction associated with this entitlement will auto renew.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement or if it was manually granted from Superwall.
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
  /// This is `nil` if there aren't any transactions that unlock this entitlement or if it was manually granted from Superwall.
  public var isInGracePeriod: Bool? {
    guard let state = state else {
      return nil
    }
    return state == .inGracePeriod
  }

  /// The state of the last subscription transaction associated with the
  /// entitlement.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement or if it was manually granted from Superwall.
  public let state: LatestSubscription.State?

  /// The type of offer that applies to the last subscription transaction that
  /// unlocks this entitlement.
  ///
  /// This is `nil` if there aren't any transactions that unlock this entitlement or if it was manually granted from Superwall.
  ///
  /// - Note: This is only non-`nil` on iOS 17.2+ or if it's a web entitlement.
  public let offerType: LatestSubscription.OfferType?

  private enum CodingKeys: String, CodingKey {
    case id = "identifier"
    case type

    case isActive
    case productIds
    case latestProductId
    case store
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
    isActive: Bool = true,
    productIds: Set<String> = [],
    latestProductId: String? = nil,
    store: EntitlementStore? = nil,
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
    self.store = store
    self.startsAt = startsAt
    self.renewedAt = renewedAt
    self.expiresAt = expiresAt
    self.isLifetime = isLifetime
    self.willRenew = willRenew
    self.state = state
    self.offerType = offerType
  }

  /// Convenience initializer for creating an entitlement with only an ID.
  ///
  /// Creates an active entitlement by default (`isActive: true`), assuming it's from the App Store.
  /// The store will be set when a transaction unlocks this entitlement.
  /// If you need to create an inactive entitlement, explicitly set `isActive: false`:
  ///
  /// ```swift
  /// Entitlement(id: "premium", isActive: false)
  /// ```
  public convenience init(
    id: String
  ) {
    self.init(
      id: id,
      type: .serviceLevel,
      store: .appStore
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.type = try container.decode(EntitlementType.self, forKey: .type)
    self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    self.productIds = try container.decodeIfPresent(Set<String>.self, forKey: .productIds) ?? []
    self.latestProductId = try container.decodeIfPresent(String.self, forKey: .latestProductId)
    self.store = try container.decodeIfPresent(EntitlementStore.self, forKey: .store)
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
    try container.encodeIfPresent(store, forKey: .store)
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
      && self.store == other.store
      && self.startsAt == other.startsAt
      && self.renewedAt == other.renewedAt
      && self.expiresAt == other.expiresAt
      && self.isLifetime == other.isLifetime
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
    hasher.combine(store)
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

// MARK: - Entitlement Merging
extension Entitlement {
  /// Determines which entitlement should take priority when merging entitlements with the same ID.
  /// Returns `true` if this entitlement should be prioritized over the other.
  ///
  /// Priority order (highest to lowest):
  /// 1. Active entitlements (isActive = true)
  /// 2. Has transaction history (latestProductId != nil)
  /// 3. Lifetime entitlements (isLifetime = true)
  /// 4. Non-revoked entitlements (isRevoked = false)
  /// 5. Latest expiry time (furthest future expiresAt)
  /// 6. Will renew vs won't renew (willRenew = true)
  /// 7. Not in grace period vs in grace period (isInGracePeriod = false)
  func shouldTakePriorityOver(_ other: Entitlement) -> Bool {
    // Both must have same ID to be compared
    guard self.id == other.id else { return false }

    // 1. Active vs inactive
    if self.isActive != other.isActive {
      return self.isActive
    }

    // 2. Has transaction history vs no transaction history
    // SUPERWALL store entitlements are manually granted and should be treated
    // as having transaction history even without latestProductId
    let selfHasTransactionHistory = self.latestProductId != nil || self.store == .superwall
    let otherHasTransactionHistory = other.latestProductId != nil || other.store == .superwall

    if selfHasTransactionHistory != otherHasTransactionHistory {
      return selfHasTransactionHistory
    }

    // 3. Lifetime takes priority (when both have same active status)
    let selfIsLifetime = self.isLifetime ?? false
    let otherIsLifetime = other.isLifetime ?? false

    if selfIsLifetime != otherIsLifetime {
      return selfIsLifetime
    }

    // 4. Non-revoked vs revoked
    let selfIsRevoked = self.isRevoked ?? false
    let otherIsRevoked = other.isRevoked ?? false

    if selfIsRevoked != otherIsRevoked {
      return !selfIsRevoked
    }

    // 5. Latest expiry time (only compare if both have expiry dates)
    if let selfExpiry = self.expiresAt,
      let otherExpiry = other.expiresAt {
      if selfExpiry != otherExpiry {
        return selfExpiry > otherExpiry
      }
    } else if self.expiresAt != nil || other.expiresAt != nil {
      // If only one has expiry, prioritize the one with expiry (means it's not lifetime)
      // But this case shouldn't happen if lifetime check passed
      return self.expiresAt != nil
    }

    // 6. Will renew vs won't renew
    // First check if one has information and the other doesn't
    if self.willRenew != nil && other.willRenew == nil {
      return true
    }
    if self.willRenew == nil && other.willRenew != nil {
      return false
    }

    // If both have information (or both nil), compare values
    let selfWillRenew = self.willRenew ?? false
    let otherWillRenew = other.willRenew ?? false

    if selfWillRenew != otherWillRenew {
      return selfWillRenew
    }

    // 7. Not in grace period vs in grace period
    // First check if one has state information and the other doesn't
    if self.state != nil && other.state == nil {
      return true
    }
    if self.state == nil && other.state != nil {
      return false
    }

    // If both have state (or both nil), prefer not in grace period
    let selfInGracePeriod = self.isInGracePeriod ?? false
    let otherInGracePeriod = other.isInGracePeriod ?? false

    if selfInGracePeriod != otherInGracePeriod {
      return !selfInGracePeriod
    }

    // If all criteria are equal, return false (no preference)
    return false
  }

  /// Merges a collection of entitlements, keeping the highest priority one for each unique ID.
  ///
  /// When merging entitlements with the same ID, the higher priority entitlement is kept,
  /// but the `productIds` from all entitlements with that ID are merged together.
  ///
  /// - Parameter entitlements: A collection of entitlements to merge
  /// - Returns: A set containing the highest priority entitlement for each unique ID with merged productIds
  static func mergePrioritized<T: Collection>(_ entitlements: T) -> Set<Entitlement> where T.Element == Entitlement {
    var mergedEntitlements: [String: Entitlement] = [:]

    for entitlement in entitlements {
      if let existing = mergedEntitlements[entitlement.id] {
        // Merge productIds from both entitlements
        let mergedProductIds = existing.productIds.union(entitlement.productIds)

        // Keep the higher priority entitlement but with merged productIds
        if entitlement.shouldTakePriorityOver(existing) {
          mergedEntitlements[entitlement.id] = Entitlement(
            id: entitlement.id,
            type: entitlement.type,
            isActive: entitlement.isActive,
            productIds: mergedProductIds,
            latestProductId: entitlement.latestProductId,
            store: entitlement.store,
            startsAt: entitlement.startsAt,
            renewedAt: entitlement.renewedAt,
            expiresAt: entitlement.expiresAt,
            isLifetime: entitlement.isLifetime,
            willRenew: entitlement.willRenew,
            state: entitlement.state,
            offerType: entitlement.offerType
          )
        } else {
          mergedEntitlements[entitlement.id] = Entitlement(
            id: existing.id,
            type: existing.type,
            isActive: existing.isActive,
            productIds: mergedProductIds,
            latestProductId: existing.latestProductId,
            store: existing.store,
            startsAt: existing.startsAt,
            renewedAt: existing.renewedAt,
            expiresAt: existing.expiresAt,
            isLifetime: existing.isLifetime,
            willRenew: existing.willRenew,
            state: existing.state,
            offerType: existing.offerType
          )
        }
      } else {
        mergedEntitlements[entitlement.id] = entitlement
      }
    }

    return Set(mergedEntitlements.values)
  }
}

// MARK: - Stubbable
extension Entitlement: Stubbable {
  static func stub() -> Entitlement {
    return Entitlement(
      id: "test",
      type: .serviceLevel,
      isActive: true
    )
  }
}

// MARK: - Set Operations with Priority
public extension Set where Element == Entitlement {
  /// Returns a new set containing the elements of this set and the given set, using priority logic.
  ///
  /// When entitlements with the same ID exist in both sets, keeps the higher priority one
  /// and merges their productIds.
  ///
  /// Example:
  /// ```swift
  /// let deviceEntitlements: Set<Entitlement> = [...]
  /// let webEntitlements: Set<Entitlement> = [...]
  /// let merged = deviceEntitlements.union(webEntitlements)
  /// ```
  func union(_ other: Set<Entitlement>) -> Set<Entitlement> {
    let combined = Array(self) + Array(other)
    return Entitlement.mergePrioritized(combined)
  }
}
