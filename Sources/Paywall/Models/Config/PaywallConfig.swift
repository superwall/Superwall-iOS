//
//  PaywallConfig.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct PaywallConfig: Decodable, Hashable {
  struct ProductConfig: Decodable, Equatable, Hashable {
    var identifier: String
  }

  var identifier: String
  var products: [ProductConfig]
}

extension PaywallConfig: Stubbable {
  static func stub() -> PaywallConfig {
    return PaywallConfig(
      identifier: "abc",
      products: [
        ProductConfig(identifier: "productIdentifier")
      ]
    )
  }
}
