//
//  ProductType.swift
//  Superwall
//
//  Created by Yusuf Tör on 01/03/2022.
//

import Foundation

/// The type of product.
public enum ProductType: String, Codable, Sendable {
  /// The primary product of the paywall.
  case primary

  /// The secondary product of the paywall.
  case secondary

  /// The tertiary product of the paywall.
  case tertiary
}

/// The product in the paywall.
public struct Product: Codable, Sendable {
  /// The type of product.
  public var type: ProductType

  /// The product identifier.
  public var id: String

  enum CodingKeys: String, CodingKey {
    case type = "product"
    case id = "productId"
  }
}
