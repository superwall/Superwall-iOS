//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/04/2022.
//

import Foundation

extension PaywallSession.Transaction.Product {
  struct Currency: Encodable {
    /// The currency code of the transacted product, e.g.  "USD"
    let code: String
    /// The currency symbol of the transacted product, e.g.  "$"
    let symbol: String

    enum CodingKeys: String, CodingKey {
      case currencySymbol = "transaction_product_currency_symbol"
      case currencyCode = "transaction_product_currency_code"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(symbol, forKey: .currencySymbol)
      try container.encode(code, forKey: .currencyCode)
    }
  }
}
