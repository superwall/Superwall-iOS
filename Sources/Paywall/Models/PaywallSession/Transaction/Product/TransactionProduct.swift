//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/04/2022.
//

import Foundation

extension PaywallSession.Transaction {
  struct Product: Encodable {
    let platformId: String

    /// Info about the period of the product
    let period: Period

    /// The trial period associated with the product, if any.
    let trialPeriod: TrialPeriod?

    /// The price of the transacted product
    let price: Price

    /// Info about the currency of the transacted product
    let currency: Currency

    /// The language code of the transacted product, e.g. en
    let languageCode: String

    /// The locale of the transacted product
    let locale: String

    enum CodingKeys: String, CodingKey {
      case platformId = "transaction_product_platform_identifier"
      case locale = "transaction_product_locale"
      case languageCode = "transaction_product_language_code"
      case hasTrial = "transaction_product_has_trial"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try price.encode(to: encoder)
      try currency.encode(to: encoder)
      try trialPeriod.encode(to: encoder)

      let hasTrial = trialPeriod != nil
      try container.encode(hasTrial, forKey: .hasTrial)

      try container.encode(platformId, forKey: .platformId)
      try container.encode(languageCode, forKey: .languageCode)
      try container.encode(locale, forKey: .locale)
    }
  }
}
