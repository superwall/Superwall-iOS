//
//  SWProductDiscount.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import StoreKit

struct SWProductDiscount: Codable {
  enum PaymentMode: String, Codable {
    case payAsYouGo
    case payUpFront
    case freeTrial
    case unknown
  }

  enum DiscountType: String, Codable, Equatable {
    case introductory
    case subscription
    case unknown
  }

  var price: Decimal
  var priceLocale: String
  var identifier: String?
  var subscriptionPeriod: SWProductSubscriptionPeriod
  var numberOfPeriods: Int
  var paymentMode: SWProductDiscount.PaymentMode
  var type: SWProductDiscount.DiscountType

  init(discount: SKProductDiscount) {
    price = discount.price as Decimal
    priceLocale = discount.priceLocale.identifier
    identifier = discount.identifier
    subscriptionPeriod = SWProductSubscriptionPeriod(
      period: discount.subscriptionPeriod,
      numberOfPeriods: discount.numberOfPeriods
    )
    numberOfPeriods = discount.numberOfPeriods

    switch discount.paymentMode {
    case .freeTrial:
      self.paymentMode = .freeTrial
    case .payAsYouGo:
      self.paymentMode = .payAsYouGo
    case .payUpFront:
      self.paymentMode = .payUpFront
    @unknown default:
      self.paymentMode = .unknown
    }

    switch discount.type {
    case .introductory:
      self.type = .introductory
    case .subscription:
      self.type = .subscription
    @unknown default:
      self.type = .unknown
    }
  }

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  init(
    offer: StoreKit.Product.SubscriptionOffer,
    fromProduct product: SK2Product
  ) {
    price = offer.price
    priceLocale = product.priceFormatStyle.locale.identifier
    identifier = offer.id
    subscriptionPeriod = SWProductSubscriptionPeriod(
      period: offer.period,
      numberOfPeriods: offer.periodCount
    )
    numberOfPeriods = offer.periodCount

    switch offer.paymentMode {
    case .freeTrial:
      self.paymentMode = .freeTrial
    case .payAsYouGo:
      self.paymentMode = .payAsYouGo
    case .payUpFront:
      self.paymentMode = .payUpFront
    default:
      self.paymentMode = .unknown
    }

    switch offer.type {
    case .introductory:
      self.type = .introductory
    case .promotional:
      self.type = .subscription
    default:
      self.type = .unknown
    }
  }
}
