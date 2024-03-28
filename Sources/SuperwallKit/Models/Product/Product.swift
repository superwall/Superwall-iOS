//
//  ProductType.swift
//  Superwall
//
//  Created by Yusuf Tör on 01/03/2022.
//

import Foundation

/// The type of product.
@objc(SWKProductType)
public enum ProductType: Int, Codable, Sendable {
  /// The primary product of the paywall.
  case primary

  /// The secondary product of the paywall.
  case secondary

  /// The tertiary product of the paywall.
  case tertiary

  enum InternalProductType: String, Codable {
    case primary
    case secondary
    case tertiary
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .primary:
      try container.encode(InternalProductType.primary.rawValue)
    case .secondary:
      try container.encode(InternalProductType.secondary.rawValue)
    case .tertiary:
      try container.encode(InternalProductType.tertiary.rawValue)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    guard let internalProductType = InternalProductType(rawValue: rawValue) else {
      throw DecodingError.typeMismatch(
        InternalProductType.self,
          .init(
            codingPath: [],
            debugDescription: "Didn't find a primary, secondary, or tertiary product type."
          )
      )
    }
    switch internalProductType {
    case .primary:
      self = .primary
    case .secondary:
      self = .secondary
    case .tertiary:
      self = .tertiary
    }
  }
}

// MARK: - CustomStringConvertible
extension ProductType: CustomStringConvertible {
  public var description: String {
    switch self {
    case .primary:
      return InternalProductType.primary.rawValue
    case .secondary:
      return InternalProductType.secondary.rawValue
    case .tertiary:
      return InternalProductType.tertiary.rawValue
    }
  }
}

/// The product in the paywall.
@objc(SWKProduct)
@objcMembers
public final class Product: NSObject, Codable, Sendable {
  /// The type of product.
  public let type: ProductType

  /// The product identifier.
  public let id: String

  enum CodingKeys: String, CodingKey {
    case type = "product"
    case id = "productId"
  }

  init(type: ProductType, id: String) {
    self.type = type
    self.id = id
  }
}

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
