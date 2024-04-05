//
//  ProductTemplate.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

struct ProductTemplate: Codable {
  var eventName: String
  var products: [ProductItem]

  enum CodingKeys: String, CodingKey {
    case eventName = "event_name"
    case products
  }
}
