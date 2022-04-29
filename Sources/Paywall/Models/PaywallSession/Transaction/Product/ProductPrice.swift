//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/04/2022.
//

import Foundation

extension PaywallSession.Transaction.Product {
  struct Price: Encodable {
    struct LocalizedPrice: Encodable {
      /// The localized price, e.g.  "$89.99"
      let value: String
      /// The amount the product costs per day, e.g. "$0.25"
      let dailyPrice: String
      /// The amount the product costs per week, e.g. "$0.25"
      let weeklyPrice: String
      /// The amount the product costs per month, e.g.  "$0.25"
      let monthlyPrice: String
      /// The amount the product costs per year, e.g.  "$0.25"
      let yearlyPrice: String
    }
    let localized: LocalizedPrice

    struct RawPrice: Encodable {
      /// The raw localized price, e.g.  "89.99"
      let value: String
      /// The raw localized price per day, e.g. "0.25"
      let dailyPrice: String
      /// The raw localized price per week, e.g. "0.25"
      let weeklyPrice: String
      /// The raw localized price per month, e.g.  "0.25"
      let monthlyPrice: String
      /// The amount the product costs per year, e.g.  "$0.25"
      let yearlyPrice: String
    }
    let raw: RawPrice

    enum CodingKeys: String, CodingKey {
      case localizedPrice = "transaction_product_price"
      case localizedDailyPrice = "transaction_product_daily_price"
      case localizedWeeklyPrice = "transaction_product_weekly_price"
      case localizedMonthlyPrice = "transaction_product_monthly_price"
      case localizedYearlyPrice = "transaction_product_yearly_price"

      case rawPrice = "transaction_product_raw_price"
      case rawDailyPrice = "transaction_product_raw_daily_price"
      case rawWeeklyPrice = "transaction_product_raw_monthly_price"
      case rawMonthlyPrice = "transaction_product_raw_weekly_price"
      case rawYearlyPrice = "transaction_product_raw_yearly_price"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try container.encode(localized.value, forKey: .localizedPrice)
      try container.encode(localized.dailyPrice, forKey: .localizedDailyPrice)
      try container.encode(localized.weeklyPrice, forKey: .localizedWeeklyPrice)
      try container.encode(localized.monthlyPrice, forKey: .localizedMonthlyPrice)
      try container.encode(localized.yearlyPrice, forKey: .localizedYearlyPrice)

      try container.encode(raw.value, forKey: .rawPrice)
      try container.encode(raw.dailyPrice, forKey: .rawDailyPrice)
      try container.encode(raw.weeklyPrice, forKey: .rawWeeklyPrice)
      try container.encode(raw.monthlyPrice, forKey: .rawMonthlyPrice)
      try container.encode(raw.yearlyPrice, forKey: .rawYearlyPrice)
    }
  }
}
