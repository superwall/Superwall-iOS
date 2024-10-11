//
//  ProductTemplate.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

struct ProductTemplate: Encodable {
  var eventName: String
  var products: [TemplatingProductItem]

  enum CodingKeys: String, CodingKey {
    case eventName = "event_name"
    case products
  }
}
