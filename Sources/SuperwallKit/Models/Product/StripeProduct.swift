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

  /// The product's store.
  private let store: String

  enum CodingKeys: String, CodingKey {
    case bundleId
    case id = "productIdentifier"
    case store
  }

  init(
    id: String,
    store: String = "STRIPE"
  ) {
    self.id = id
    self.store = store
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(store, forKey: .store)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
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
      && store == other.store
  }

  public override var hash: Int {
    var hasher = Hasher()
    hasher.combine(id)
    hasher.combine(store)
    return hasher.finalize()
  }
}
