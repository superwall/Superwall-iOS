//
//  CheckoutStatusResponse.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 18/07/2025.
//

import Foundation

struct CheckoutStatusResponse: Decodable {
  struct AbandonedCheckout {
    let paywallId: String
    let variantId: String
    let presentedByEventName: String
    let stripeProduct: StripeProductType
  }

  enum CheckoutStatus: Decodable {
    case pending
    case completed(redemptionCodes: [String])
    case abandoned(AbandonedCheckout)

    private enum CodingKeys: String, CodingKey {
      case type
      case redemptionCodes
      case paywallId
      case experimentVariantId
      case presentedByEventName
      case productId
      case price
      case rawPrice
      case currencyCode
      case currencySymbol
      case priceLocale
      case subscriptionPeriod
      case subscriptionIntroductoryOffer
    }
    
    private enum PriceLocaleCodingKeys: String, CodingKey {
      case identifier
      case languageCode
      case currencyCode
      case currencySymbol
    }
    
    private enum SubscriptionPeriodCodingKeys: String, CodingKey {
      case unit
      case value
    }
    
    private enum SubscriptionIntroOfferCodingKeys: String, CodingKey {
      case period
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      
      switch type {
      case "pending":
        self = .pending
      case "completed":
        let redemptionCodes = try container.decode([String].self, forKey: .redemptionCodes)
        self = .completed(redemptionCodes: redemptionCodes)
      case "abandoned":
        // Decode priceLocale
        let priceLocaleContainer = try container.nestedContainer(keyedBy: PriceLocaleCodingKeys.self, forKey: .priceLocale)
        let priceLocale = StripeProductType.PriceLocale(
          identifier: try priceLocaleContainer.decode(String.self, forKey: .identifier),
          languageCode: try priceLocaleContainer.decode(String.self, forKey: .languageCode),
          currencyCode: try priceLocaleContainer.decode(String.self, forKey: .currencyCode),
          currencySymbol: try priceLocaleContainer.decode(String.self, forKey: .currencySymbol)
        )
        
        // Decode optional subscriptionPeriod
        let subscriptionPeriod: StripeProductType.StripeSubscriptionPeriod?
        if container.contains(.subscriptionPeriod) {
          let subscriptionPeriodContainer = try container.nestedContainer(keyedBy: SubscriptionPeriodCodingKeys.self, forKey: .subscriptionPeriod)
          subscriptionPeriod = StripeProductType.StripeSubscriptionPeriod(
            unit: try subscriptionPeriodContainer.decode(StripeProductType.StripeSubscriptionPeriod.Unit.self, forKey: .unit),
            value: try subscriptionPeriodContainer.decode(Int.self, forKey: .value)
          )
        } else {
          subscriptionPeriod = nil
        }
        
        // Decode optional subscriptionIntroductoryOffer
        let subscriptionIntroOffer: StripeProductType.SubscriptionIntroductoryOffer?
        if container.contains(.subscriptionIntroductoryOffer) {
          let subscriptionIntroOfferContainer = try container.nestedContainer(keyedBy: SubscriptionIntroOfferCodingKeys.self, forKey: .subscriptionIntroductoryOffer)
          let periodContainer = try subscriptionIntroOfferContainer.nestedContainer(keyedBy: SubscriptionPeriodCodingKeys.self, forKey: .period)
          let period = StripeProductType.StripeSubscriptionPeriod(
            unit: try periodContainer.decode(StripeProductType.StripeSubscriptionPeriod.Unit.self, forKey: .unit),
            value: try periodContainer.decode(Int.self, forKey: .value)
          )
          subscriptionIntroOffer = StripeProductType.SubscriptionIntroductoryOffer(period: period)
        } else {
          subscriptionIntroOffer = nil
        }

        let product = StripeProductType(
          id: try container.decode(String.self, forKey: .productId),
          price: try container.decode(Decimal.self, forKey: .rawPrice),
          localizedPrice: try container.decode(String.self, forKey: .price),
          currencyCode: try container.decode(String.self, forKey: .currencyCode),
          currencySymbol: try container.decode(String.self, forKey: .currencySymbol),
          priceLocale: priceLocale,
          stripeSubscriptionPeriod: subscriptionPeriod,
          subscriptionIntroOffer: subscriptionIntroOffer,
          entitlements: []
        )

        let abandonedCheckout = AbandonedCheckout(
          paywallId: try container.decode(String.self, forKey: .paywallId),
          variantId: try container.decode(String.self, forKey: .experimentVariantId),
          presentedByEventName: try container.decode(String.self, forKey: .presentedByEventName),
          stripeProduct: product
        )
        self = .abandoned(abandonedCheckout)
      default:
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Unknown checkout status type: \(type)"
          )
        )
      }
    }
  }

  let status: CheckoutStatus

  private enum CodingKeys: String, CodingKey {
    case status
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.status = try container.decode(CheckoutStatus.self, forKey: .status)
  }
}
