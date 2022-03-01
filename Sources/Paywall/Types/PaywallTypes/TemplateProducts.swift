//
//  TemplateProduct.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

struct TemplateProducts: Codable {
  var eventName: String
  var products: [Product]

  enum CodingKeys: String, CodingKey {
    case eventName = "event_name"
    case products
  }
}
