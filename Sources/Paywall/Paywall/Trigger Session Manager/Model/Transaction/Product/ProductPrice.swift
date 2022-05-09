//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/05/2022.
//

import Foundation

struct Price: Codable {
  let description: String

  let daily: String
  let weekly: String
  let monthly: String
  let yearly: String

  enum CodingKeys: String, CodingKey {
    case description = "transacting_product_price_str"
    case daily = "transacting_product_daily_price_str"
    case weekly = "transacting_product_weekly_price_str"
    case monthly = "transacting_product_monthly_price_str"
    case yearly = "transacting_product_yearly_price_str"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(description, forKey: .description)
    try container.encode(daily, forKey: .daily)
    try container.encode(weekly, forKey: .weekly)
    try container.encode(monthly, forKey: .monthly)
    try container.encode(yearly, forKey: .yearly)
  }
}
