//
//  ProductStore.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/07/2025.
//

import Foundation

/// An enum whose types specify the store which the product belongs to.
@objc(SWKProductStore)
public enum ProductStore: Int, Codable, Sendable {
  /// An Apple App Store product.
  case appStore

  /// A Stripe product.
  case stripe

  /// Returns the string representation of the product store (e.g., "APP_STORE", "STRIPE")
  public var description: String {
    switch self {
    case .appStore:
      return CodingKeys.appStore.rawValue
    case .stripe:
      return CodingKeys.stripe.rawValue
    }
  }

  enum CodingKeys: String, CodingKey {
    case appStore = "APP_STORE"
    case stripe = "STRIPE"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .appStore:
      try container.encode(CodingKeys.appStore.rawValue)
    case .stripe:
      try container.encode(CodingKeys.stripe.rawValue)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let type = CodingKeys(rawValue: rawValue)
    switch type {
    case .appStore:
      self = .appStore
    case .stripe:
      self = .stripe
    case .none:
      throw DecodingError.valueNotFound(
        String.self,
        .init(
          codingPath: [],
          debugDescription: "Unsupported product store type."
        )
      )
    }
  }
}
