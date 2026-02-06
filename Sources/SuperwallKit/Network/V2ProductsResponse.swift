//
//  SuperwallProductsResponse.swift
//  Superwall
//
//  Created by Claude on 2026-01-26.
//

import Foundation

/// Response from the /v1/products endpoint containing a list of products.
struct SuperwallProductsResponse: Decodable {
  /// The list of products.
  let data: [SuperwallProduct]
}

/// A product from the Superwall catalog.
public struct SuperwallProduct: Decodable, Sendable {
  /// The type of object (always "product").
  public let object: String

  /// The product identifier (e.g., App Store product ID).
  public let identifier: String

  /// The platform this product is for.
  public let platform: SuperwallProductPlatform

  /// The price of the product.
  public let price: SuperwallProductPrice?

  /// Subscription details if this is a subscription product.
  public let subscription: SuperwallProductSubscription?

  /// The entitlements associated with this product.
  public let entitlements: [SuperwallEntitlementRef]

  /// The storefront country code for pricing (e.g., "USA").
  public let storefront: String
}

/// Reference to an entitlement.
public struct SuperwallEntitlementRef: Decodable, Sendable {
  /// The entitlement identifier.
  public let identifier: String

  /// The type of entitlement.
  public let type: String
}

/// The platform a product is available on.
public enum SuperwallProductPlatform: String, Decodable, Sendable {
  case ios
  case android
  case stripe
  case paddle
  case superwall
}

/// Price information for a product.
public struct SuperwallProductPrice: Decodable, Sendable {
  /// The price amount in cents.
  public let amount: Int

  /// The currency code (e.g., "USD").
  public let currency: String
}

/// Subscription details for a product.
public struct SuperwallProductSubscription: Decodable, Sendable {
  /// The subscription period unit.
  public let period: SuperwallSubscriptionPeriod

  /// The number of periods in each billing cycle.
  public let periodCount: Int

  /// The number of trial days, if any.
  public let trialPeriodDays: Int?

  enum CodingKeys: String, CodingKey {
    case period
    case periodCount = "period_count"
    case trialPeriodDays = "trial_period_days"
  }
}

/// The unit of a subscription period.
public enum SuperwallSubscriptionPeriod: String, Decodable, Sendable {
  case day
  case week
  case month
  case year
}
