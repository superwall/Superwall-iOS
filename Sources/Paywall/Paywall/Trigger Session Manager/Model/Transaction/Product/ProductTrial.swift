//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/05/2022.
//

import Foundation


extension TriggerSession.Transaction.Product {
  struct Trial: Codable {
    /// Info about the period of the product
    let period: Period?

    let dailyPrice: String?
    let weeklyPrice: String?
    let monthlyPrice: String?
    let yearlyPrice: String?

    enum CodingKeys: String, CodingKey {
      case daily = "transacting_product_trial_daily_price_str"
      case weekly = "transacting_product_trial_weekly_price_str"
      case monthly = "transacting_product_trial_monthly_price_str"
      case yearly = "transacting_product_trial_yearly_price_str"

      case periodUnit = "transacting_product_trial_period_unit"
      case periodCount = "transacting_product_trial_period_count"
      case periodDays = "transacting_product_trial_period_days"
    }

    init(
      period: Period?,
      dailyPrice: String?,
      weeklyPrice: String?,
      monthlyPrice: String?,
      yearlyPrice: String?
    ) {
      self.period = period
      self.dailyPrice = dailyPrice
      self.weeklyPrice = weeklyPrice
      self.monthlyPrice = monthlyPrice
      self.yearlyPrice = yearlyPrice
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      dailyPrice = try values.decodeIfPresent(String.self, forKey: .daily)
      weeklyPrice = try values.decodeIfPresent(String.self, forKey: .daily)
      monthlyPrice = try values.decodeIfPresent(String.self, forKey: .daily)
      yearlyPrice = try values.decodeIfPresent(String.self, forKey: .daily)

      let unit = try values.decodeIfPresent(SWProductSubscriptionPeriod.Unit.self, forKey: .periodUnit)
      let count = try values.decodeIfPresent(Int.self, forKey: .periodCount)
      let days = try values.decodeIfPresent(Int.self, forKey: .periodDays)

      if let unit = unit,
        let count = count,
        let days = days {
        period = Period(unit: unit, count: count, days: days)
      } else {
        period = nil
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try container.encodeIfPresent(dailyPrice, forKey: .daily)
      try container.encodeIfPresent(weeklyPrice, forKey: .weekly)
      try container.encodeIfPresent(monthlyPrice, forKey: .monthly)
      try container.encodeIfPresent(yearlyPrice, forKey: .yearly)

      try container.encodeIfPresent(period?.unit, forKey: .periodUnit)
      try container.encodeIfPresent(period?.count, forKey: .periodCount)
      try container.encodeIfPresent(period?.days, forKey: .periodDays)
    }
  }
}
