//
//  SubscriptionTransaction.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 15/07/2025.
//

import Foundation

/// Represents a subscription in the customer's purchase history.
@objc(SWKSubscriptionTransaction)
@objcMembers
public final class SubscriptionTransaction: NSObject, Codable {
  /// The unique identifier for the transaction.
  public let transactionId: String

  /// The product identifier of the subscription.
  public let productId: String

  /// The date that the App Store charged the user's account.
  public let purchaseDate: Date

  /// Indicates whether the subscription will renew.
  public internal(set) var willRenew: Bool

  /// Indicates whether the transaction has been revoked.
  public let isRevoked: Bool

  /// Indicates whether the subscription is in a billing grace period state.
  public internal(set) var isInGracePeriod: Bool

  /// Indicates whether the subscription is in a billing retry period state.
  public internal(set) var isInBillingRetryPeriod: Bool

  /// Indicates whether the subscription is active.
  public let isActive: Bool

  /// The date that the subscription expires.
  ///
  /// This is `nil` if it's a non-renewing subscription.
  public let expirationDate: Date?

  /// The type of offer applied to this transaction (trial, code, promotional, winback).
  ///
  /// This is `nil` if no offer was applied or on iOS versions below 17.2.
  public let offerType: LatestSubscription.OfferType?

  /// The subscription group identifier for this subscription.
  ///
  /// This is `nil` if the subscription group couldn't be determined.
  public let subscriptionGroupId: String?

  /// The store where this subscription was purchased.
  public let store: ProductStore

  init(
    transactionId: String,
    productId: String,
    purchaseDate: Date,
    willRenew: Bool,
    isRevoked: Bool,
    isInGracePeriod: Bool,
    isInBillingRetryPeriod: Bool,
    isActive: Bool,
    expirationDate: Date?,
    offerType: LatestSubscription.OfferType? = nil,
    subscriptionGroupId: String? = nil,
    store: ProductStore = .appStore
  ) {
    self.transactionId = transactionId
    self.productId = productId
    self.purchaseDate = purchaseDate
    self.willRenew = willRenew
    self.isRevoked = isRevoked
    self.isInGracePeriod = isInGracePeriod
    self.isInBillingRetryPeriod = isInBillingRetryPeriod
    self.isActive = isActive
    self.expirationDate = expirationDate
    self.offerType = offerType
    self.subscriptionGroupId = subscriptionGroupId
    self.store = store
  }

  override public func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? SubscriptionTransaction else {
      return false
    }
    return self.transactionId == other.transactionId &&
      self.productId == other.productId &&
      self.purchaseDate == other.purchaseDate &&
      self.willRenew == other.willRenew &&
      self.isRevoked == other.isRevoked &&
      self.isInGracePeriod == other.isInGracePeriod &&
      self.isInBillingRetryPeriod == other.isInBillingRetryPeriod &&
      self.isActive == other.isActive &&
      self.expirationDate == other.expirationDate &&
      self.offerType == other.offerType &&
      self.subscriptionGroupId == other.subscriptionGroupId &&
      self.store == other.store
  }

  override public var hash: Int {
    var hasher = Hasher()
    hasher.combine(transactionId)
    hasher.combine(productId)
    hasher.combine(purchaseDate)
    hasher.combine(willRenew)
    hasher.combine(isRevoked)
    hasher.combine(isInGracePeriod)
    hasher.combine(isInBillingRetryPeriod)
    hasher.combine(isActive)
    hasher.combine(expirationDate)
    hasher.combine(offerType)
    hasher.combine(subscriptionGroupId)
    hasher.combine(store)
    return hasher.finalize()
  }

  private enum CodingKeys: String, CodingKey {
    case transactionId
    case productId
    case purchaseDate
    case willRenew
    case isRevoked
    case isInGracePeriod
    case isInBillingRetryPeriod
    case isActive
    case expirationDate
    case offerType
    case subscriptionGroupId
    case store
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    transactionId = try container.decode(String.self, forKey: .transactionId)
    productId = try container.decode(String.self, forKey: .productId)
    purchaseDate = try container.decode(Date.self, forKey: .purchaseDate)
    willRenew = try container.decode(Bool.self, forKey: .willRenew)
    isRevoked = try container.decode(Bool.self, forKey: .isRevoked)
    isInGracePeriod = try container.decode(Bool.self, forKey: .isInGracePeriod)
    isInBillingRetryPeriod = try container.decode(Bool.self, forKey: .isInBillingRetryPeriod)
    isActive = try container.decode(Bool.self, forKey: .isActive)
    expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
    offerType = try container.decodeIfPresent(LatestSubscription.OfferType.self, forKey: .offerType)
    subscriptionGroupId = try container.decodeIfPresent(String.self, forKey: .subscriptionGroupId)
    store = try container.decode(ProductStore.self, forKey: .store)
    super.init()
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(transactionId, forKey: .transactionId)
    try container.encode(productId, forKey: .productId)
    try container.encode(purchaseDate, forKey: .purchaseDate)
    try container.encode(willRenew, forKey: .willRenew)
    try container.encode(isRevoked, forKey: .isRevoked)
    try container.encode(isInGracePeriod, forKey: .isInGracePeriod)
    try container.encode(isInBillingRetryPeriod, forKey: .isInBillingRetryPeriod)
    try container.encode(isActive, forKey: .isActive)
    try container.encodeIfPresent(expirationDate, forKey: .expirationDate)
    try container.encodeIfPresent(offerType, forKey: .offerType)
    try container.encodeIfPresent(subscriptionGroupId, forKey: .subscriptionGroupId)
    try container.encode(store, forKey: .store)
  }
}
