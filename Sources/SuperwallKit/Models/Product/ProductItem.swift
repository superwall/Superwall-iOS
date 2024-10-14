//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/03/2024.
//

import Foundation

/// An enum whose types specify the store which the product belongs to.
@objc(SWKProductStore)
public enum ProductStore: Int, Codable, Sendable {
  /// An Apple App Store product.
  case appStore

  enum CodingKeys: String, CodingKey {
    case appStore = "APP_STORE"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .appStore:
      try container.encode(CodingKeys.appStore.rawValue)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let type = CodingKeys(rawValue: rawValue)
    switch type {
    case .appStore:
      self = .appStore
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

/// An Apple App Store product.
@objc(SWKAppStoreProduct)
@objcMembers
public final class AppStoreProduct: NSObject, Codable, Sendable {
  /// The store the product belongs to.
  let store: ProductStore

  /// The product identifier.
  public let id: String

  enum CodingKeys: String, CodingKey {
    case id = "productIdentifier"
    case store
  }

  init(
    store: ProductStore = .appStore,
    id: String
  ) {
    self.store = store
    self.id = id
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(store, forKey: .store)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.store = try container.decode(Store.self, forKey: .store)
    super.init()
  }
}

/// An objc-only type that specifies a store and a product.
@objc(SWKStoreProductAdapter)
@objcMembers
public final class StoreProductAdapterObjc: NSObject, Codable, Sendable {
  /// The store associated with the product.
  public let store: ProductStore

  /// The App Store product. This is non-nil if `store` is
  /// `appStore`.
  public let appStoreProduct: AppStoreProduct?

  init(
    store: ProductStore,
    appStoreProduct: AppStoreProduct?
  ) {
    self.store = store
    self.appStoreProduct = appStoreProduct
  }
}

/// The product in the paywall.
@objc(SWKProduct)
@objcMembers
public final class Product: NSObject, Codable, Sendable {
  /// The type of store and its associated product.
  public enum StoreProductType: Codable, Sendable {
    case appStore(AppStoreProduct)
  }

  private enum CodingKeys: String, CodingKey {
    case name = "referenceName"
    case storeProduct
    case entitlements
  }

  /// The name of the product in the editor.
  public let name: String

  /// The type of product
  public let type: StoreProductType

  /// Convenience variable that accesses the product's identifier.
  public var id: String {
    switch type {
    case .appStore(let product):
      return product.id
    }
  }

  /// The entitlement associated with the product.
  public let entitlements: Set<Entitlement>

  /// The objc-only type of product.
  @objc(adapter)
  public let objcAdapter: StoreProductAdapterObjc

  init(
    name: String,
    type: StoreProductType,
    entitlements: Set<Entitlement>
  ) {
    self.name = name
    self.type = type
    self.entitlements = entitlements

    switch type {
    case .appStore(let product):
      objcAdapter = .init(
        store: .appStore,
        appStoreProduct: product
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(name, forKey: .name)

    try container.encode(entitlements, forKey: .entitlements)

    switch type {
    case .appStore(let product):
      try container.encode(product, forKey: .storeProduct)
    }
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)

    // These will throw an error if the StoreProduct is not an AppStoreProduct or if the
    // entitlement type is not `SERVICE_LEVEL`, which must be caught in a `Throwable` and
    // ignored in the paywall object.
    entitlements = try container.decode(Set<Entitlement>.self, forKey: .entitlements)
    let storeProduct = try container.decode(AppStoreProduct.self, forKey: .storeProduct)
    type = .appStore(storeProduct)
    objcAdapter = .init(store: .appStore, appStoreProduct: storeProduct)
  }
}

struct TemplatingProductItem: Encodable {
  let name: String
  let productId: String

  private enum CodingKeys: String, CodingKey {
    case product
    case productId
  }

  static func create(from productItems: [ProductItem]) -> [TemplatingProductItem] {
    return productItems.map { TemplatingProductItem(name: $0.name, productId: $0.id) }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    // Encode name as "product" for templating
    try container.encode(name, forKey: .product)

    // Encode product ID as "productId" for templating
    try container.encode(productId, forKey: .productId)
  }
}
