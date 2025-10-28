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

  /// A Paddle product.
  case paddle

  /// A Google Play Store product.
  case playStore

  /// A manually granted entitlement from the Superwall dashboard.
  case superwall

  /// Other/Unknown store.
  case other

  enum CodingKeys: String, CodingKey {
    case appStore = "APP_STORE"
    case stripe = "STRIPE"
    case paddle = "PADDLE"
    case playStore = "PLAY_STORE"
    case superwall = "SUPERWALL"
    case other = "OTHER"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .appStore:
      try container.encode(CodingKeys.appStore.rawValue)
    case .stripe:
      try container.encode(CodingKeys.stripe.rawValue)
    case .paddle:
      try container.encode(CodingKeys.paddle.rawValue)
    case .playStore:
      try container.encode(CodingKeys.playStore.rawValue)
    case .superwall:
      try container.encode(CodingKeys.superwall.rawValue)
    case .other:
      try container.encode(CodingKeys.other.rawValue)
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
    case .paddle:
      self = .paddle
    case .playStore:
      self = .playStore
    case .superwall:
      self = .superwall
    case .other:
      self = .other
    case .none:
      // Default to other for unknown stores
      self = .other
    }
  }
}
