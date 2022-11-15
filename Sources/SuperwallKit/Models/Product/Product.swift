//
//  ProductType.swift
//  Superwall
//
//  Created by Yusuf Tör on 01/03/2022.
//

import Foundation

public enum ProductType: String, Codable {
  case primary
  case secondary
  case tertiary
}

public struct Product: Codable {
  public var type: ProductType
  public var id: String

  enum CodingKeys: String, CodingKey {
    case type = "product"
    case id = "productId"
  }
}
