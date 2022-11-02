//
//  Postback.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation
import StoreKit

struct Postback: Codable {
  var products: [PostbackProduct]
}

struct PostbackProduct: Codable {
  var identifier: String
  var productVariables: JSON
  var product: SWProduct

  init(product: SKProduct) {
    self.identifier = product.productIdentifier
    self.productVariables = product.swProductTemplateVariablesJson
    self.product = SWProduct(product: product)
  }
}
