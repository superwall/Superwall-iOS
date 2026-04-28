//
//  StripeProduct.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/07/2025.
//

import Foundation

/// A Stripe product.
@objc(SWKStripeProduct)
@objcMembers
public final class StripeProduct: NSObject, Codable, Sendable {
  /// The product identifier.
  public let id: String

  /// The number of trial days for this product, if any.
  public let trialDays: Int?

  /// The product's store.
  private let store: String

  enum CodingKeys: String, CodingKey {
    case bundleId
    case id = "productIdentifier"
    case store
    case trialDays
  }

  init(
    id: String,
    trialDays: Int? = nil,
    store: String = "STRIPE"
  ) {
    self.id = id
    self.trialDays = trialDays
    self.store = store
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(store, forKey: .store)
    try container.encodeIfPresent(trialDays, forKey: .trialDays)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    trialDays = try container.decodeIfPresent(Int.self, forKey: .trialDays)
    store = try container.decode(String.self, forKey: .store)
    if store != "STRIPE" {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Not a Stripe product \(store)"
        )
      )
    }
    super.init()
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? StripeProduct else {
      return false
    }
    return id == other.id
      && trialDays == other.trialDays
      && store == other.store
  }

  public override var hash: Int {
    var hasher = Hasher()
    hasher.combine(id)
    hasher.combine(trialDays)
    hasher.combine(store)
    return hasher.finalize()
  }
}
