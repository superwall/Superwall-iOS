//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/04/2022.
//

import Foundation

extension TriggerSession.Transaction.Product {
  struct TrialPeriod: Encodable {
    /// The days in the trial period, e.g. "2"
    let days: String
    /// The weeks in the trial period, e.g. "2"
    let weeks: String
    /// The months in the trial period, e.g. "12"
    let months: String
    /// The years in the trial period, e.g. "0"
    let years: String
    /// The text version of the trial period, e.g. "7-day"
    let text: String

    enum CodingKeys: String, CodingKey {
      case days = "transaction_product_trial_period_days"
      case weeks = "transaction_product_trial_period_weeks"
      case months = "transaction_product_trial_period_months"
      case years = "transaction_product_trial_period_years"
      case text = "transaction_product_trial_period_text"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try container.encode(days, forKey: .days)
      try container.encode(weeks, forKey: .weeks)
      try container.encode(months, forKey: .months)
      try container.encode(years, forKey: .years)
      try container.encode(text, forKey: .text)
    }
  }
}
