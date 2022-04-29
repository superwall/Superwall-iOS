//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/04/2022.
//

import Foundation

extension PaywallSession.Transaction.Product {
  struct Period: Encodable {
    /// The period, e.g. "year"
    let value: String
    /// The alternative period of the product, e.g. "1 yr"
    let alternative: String
    /// The period of the product ending in ly, e.g. "yearly"
    let ly: String
    /// The localized period, e.g. "1 yr"
    let localized: String
    /// The weekly duration of the product, e.g. "52"
    let weeks: String
    /// The monthly duration of the product, e.g. "12"
    let months: String
    /// The years duration of the product, e.g. "1"
    let years: String

    enum CodingKeys: String, CodingKey {
      case value = "transaction_product_period"
      case alternative = "transaction_product_period_alt"
      case ly = "transaction_product_period_ly"
      case localized = "transaction_product_period_localized"
      case weeks = "transaction_product_period_weeks"
      case months = "transaction_product_period_months"
      case years = "transaction_product_period_years"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(value, forKey: .value)
      try container.encode(alternative, forKey: .alternative)
      try container.encode(ly, forKey: .ly)
      try container.encode(localized, forKey: .localized)
      try container.encode(weeks, forKey: .weeks)
      try container.encode(months, forKey: .months)
      try container.encode(years, forKey: .years)
    }
  }
}
