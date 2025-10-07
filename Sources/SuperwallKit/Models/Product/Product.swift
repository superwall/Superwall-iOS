//
//  File.swift
//
//
//  Created by Yusuf Tör on 29/03/2024.
//

import Foundation

/// The product in the paywall.
@objc(SWKProduct)
@objcMembers
public final class Product: NSObject, Codable, Sendable {
  /// The type of store and its associated product.
  public enum StoreProductType: Codable, Sendable, Hashable {
    case appStore(AppStoreProduct)
    case stripe(StripeProduct)
  }

  private enum CodingKeys: String, CodingKey {
    case name = "referenceName"
    case storeProduct
    case swCompositeProductId
    case entitlements
  }

  /// The name of the product in the editor.
  ///
  /// This is optional because products can also be decoded from outside
  /// of a paywall.
  public let name: String?

  /// The type of product
  public let type: StoreProductType

  /// The product's identifier.
  public let id: String

  /// The entitlement associated with the product.
  public let entitlements: Set<Entitlement>

  /// The objc-only type of product.
  @objc(adapter)
  public let objcAdapter: StoreProductAdapterObjc

  init(
    name: String?,
    type: StoreProductType,
    id: String,
    entitlements: Set<Entitlement>
  ) {
    self.name = name
    self.type = type
    self.id = id
    self.entitlements = entitlements

    switch type {
    case .appStore(let product):
      objcAdapter = .init(
        store: .appStore,
        appStoreProduct: product,
        stripeProduct: nil
      )
    case .stripe(let product):
      objcAdapter = .init(
        store: .stripe,
        appStoreProduct: nil,
        stripeProduct: product
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encodeIfPresent(name, forKey: .name)

    try container.encode(entitlements, forKey: .entitlements)
    try container.encode(id, forKey: .swCompositeProductId)

    switch type {
    case .appStore(let product):
      try container.encode(product, forKey: .storeProduct)
    case .stripe(let product):
      try container.encode(product, forKey: .storeProduct)
    }
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decodeIfPresent(String.self, forKey: .name)

    // These will throw an error if the StoreProduct is not an AppStoreProduct/StripeProduct
    // or if the entitlement type is not `SERVICE_LEVEL`, which must be caught in a
    // `Throwable` and ignored in the paywall object.
    entitlements = try container.decode(Set<Entitlement>.self, forKey: .entitlements)

    do {
      let appStoreProduct = try container.decode(AppStoreProduct.self, forKey: .storeProduct)
      type = .appStore(appStoreProduct)
      objcAdapter = .init(
        store: .appStore,
        appStoreProduct: appStoreProduct,
        stripeProduct: nil
      )
      // Try to decode from swCompositeProductId, fallback to computing from type
      if let decodedId = try? container.decode(String.self, forKey: .swCompositeProductId) {
        id = decodedId
      } else {
        id = appStoreProduct.id
      }
    } catch {
      let stripeProduct = try container.decode(StripeProduct.self, forKey: .storeProduct)
      type = .stripe(stripeProduct)
      objcAdapter = .init(
        store: .stripe,
        appStoreProduct: nil,
        stripeProduct: stripeProduct
      )
      // Try to decode from swCompositeProductId, fallback to computing from type
      if let decodedId = try? container.decode(String.self, forKey: .swCompositeProductId) {
        id = decodedId
      } else {
        id = stripeProduct.id
      }
    }
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? Product else {
      return false
    }
    return name == other.name
    && type == other.type
    && entitlements == other.entitlements
  }

  public override var hash: Int {
    var hasher = Hasher()
    hasher.combine(name)
    hasher.combine(type)
    hasher.combine(entitlements)
    return hasher.finalize()
  }
}

struct TemplatingProductItem: Encodable {
  let name: String
  let productId: String

  private enum CodingKeys: String, CodingKey {
    case product
    case productId
  }

  static func create(from productItems: [Product]) -> [TemplatingProductItem] {
    return productItems.compactMap {
      guard let name = $0.name else {
        return nil
      }
      return TemplatingProductItem(
        name: name,
        productId: $0.id
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    // Encode name as "product" for templating
    try container.encode(name, forKey: .product)

    // Encode product ID as "productId" for templating
    try container.encode(productId, forKey: .productId)
  }
}
