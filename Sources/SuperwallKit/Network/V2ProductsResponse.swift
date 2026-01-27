//
//  V2ProductsResponse.swift
//  Superwall
//
//  Created by Claude on 2026-01-26.
//

import Foundation

/// Response from the /v2/products endpoint containing a list of products.
struct V2ProductsResponse: Decodable {
  /// The list of products.
  let data: [V2Product]
}

/// A product from the Superwall catalog (v2 API).
public struct V2Product: Decodable, Sendable {
  /// The unique identifier for the product.
  public let id: Int

  /// The type of object (always "product").
  public let object: String

  /// The application ID this product belongs to.
  public let application: Int

  /// The product identifier (e.g., App Store product ID).
  public let identifier: String

  /// The display name of the product.
  public let name: String?

  /// The platform this product is for.
  public let platform: V2ProductPlatform

  /// The price of the product.
  public let price: V2ProductPrice?

  /// Subscription details if this is a subscription product.
  public let subscription: V2ProductSubscription?

  /// The entitlement IDs associated with this product.
  public let entitlements: [Int]

  /// When the product was created.
  public let createdAt: String

  /// When the product was last updated.
  public let updatedAt: String

  /// Arbitrary metadata associated with the product.
  public let metadata: [String: AnyCodable]?

  enum CodingKeys: String, CodingKey {
    case id, object, application, identifier, name, platform
    case price, subscription, entitlements, metadata
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

/// The platform a product is available on.
public enum V2ProductPlatform: String, Decodable, Sendable {
  case ios
  case android
  case stripe
  case paddle
}

/// Price information for a product.
public struct V2ProductPrice: Decodable, Sendable {
  /// The price amount in cents.
  public let amount: Int

  /// The currency code (e.g., "USD").
  public let currency: String
}

/// Subscription details for a product.
public struct V2ProductSubscription: Decodable, Sendable {
  /// The subscription period unit.
  public let period: V2SubscriptionPeriod

  /// The number of periods in each billing cycle.
  public let periodCount: Int

  /// The number of trial days, if any.
  public let trialPeriodDays: Int?

  /// Introductory offer details, if any.
  public let introductoryOffer: V2IntroductoryOffer?

  enum CodingKeys: String, CodingKey {
    case period
    case periodCount = "period_count"
    case trialPeriodDays = "trial_period_days"
    case introductoryOffer = "introductory_offer"
  }
}

/// The unit of a subscription period.
public enum V2SubscriptionPeriod: String, Decodable, Sendable {
  case day
  case week
  case month
  case year
}

/// Introductory offer details.
public struct V2IntroductoryOffer: Decodable, Sendable {
  /// The type of introductory offer.
  public let type: V2IntroOfferType

  /// The duration of the offer in days.
  public let durationDays: Int

  enum CodingKeys: String, CodingKey {
    case type
    case durationDays = "duration_days"
  }
}

/// The type of introductory offer.
public enum V2IntroOfferType: String, Decodable, Sendable {
  case freeTrial = "free_trial"
  case payAsYouGo = "pay_as_you_go"
  case payUpFront = "pay_up_front"
}

/// A type-erased Codable value for handling arbitrary JSON.
public struct AnyCodable: Decodable, @unchecked Sendable {
  public let value: Any

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      value = NSNull()
    } else if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let array = try? container.decode([AnyCodable].self) {
      value = array.map { $0.value }
    } else if let dict = try? container.decode([String: AnyCodable].self) {
      value = dict.mapValues { $0.value }
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unable to decode value"
      )
    }
  }
}
