//
//  ProductType.swift
//  Paywall
//
//  Created by Yusuf Tör on 01/03/2022.
//

import Foundation

enum ProductType: String, Codable {
  case primary
  case secondary
  case tertiary
}

struct Product: Codable {
  var type: ProductType
  var id: String
}
