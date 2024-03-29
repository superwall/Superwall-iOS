//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/03/2024.
//

import Foundation

/// The product in the paywall.
@objc(SWKProductItem)
@objcMembers
public final class ProductItem: NSObject, Codable, Sendable {
  public enum Store: Codable, Sendable {
    /// An Apple App Store product.
    case appStore

    /// A Google Play Store product.
    case playStore

    /// An unsupported store type.
    case unknown
  }

  /// The label attached to the product.
  public let name: String

  /// The product identifier.
  public let id: String

  /// The ``ProductItem/Store-swift.enum`` the product belongs to.
  public let store: Store

  private enum CodingKeys: String, CodingKey {
    case product
    case name
    case id
    case productId
    case store
  }

  init(
    name: String,
    id: String,
    store: Store
  ) {
    self.name = name
    self.id = id
    self.store = store
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    // Encode name as "product" for templating
    try container.encode(name, forKey: .product)

    // Encode name as "productId" for templating
    try container.encode(id, forKey: .productId)

    try container.encode(store, forKey: .store)
  }

  // Custom decoding to handle the specific key requirements
  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    id = try container.decode(String.self, forKey: .id)

    do {
      store = try container.decode(Store.self, forKey: .store)
    } catch {
      store = .unknown
    }
  }
}
