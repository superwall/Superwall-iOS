//
//  SK2StoreProductDiscount 2.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/07/2025.
//


//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  SK2StoreProductDiscount.swift
//
//  Created by Nacho Soto on 1/17/22.
//  Updated by Yusuf Tör from Superwall on 11/8/22.

import StoreKit

struct StripeStoreProductDiscount: StoreProductDiscountType {
  let offerIdentifier: String?
  let currencyCode: String?
  let price: Decimal
  let paymentMode: StoreProductDiscount.PaymentMode
  let subscriptionPeriod: SubscriptionPeriod
  let numberOfPeriods: Int
  let type: StoreProductDiscount.DiscountType
  let localizedPriceString: String

  init?(
    stripeOffer: StripeProductType.SubscriptionIntroductoryOffer,
    currencyCode: String?
  ) {
    guard
      let paymentMode = StoreProductDiscount.PaymentMode(subscriptionOfferPaymentMode: stripeOffer.paymentMethod),
      let subscriptionPeriod = SubscriptionPeriod.from(stripeSubscriptionPeriod: stripeOffer.period)
    else {
      return nil
    }

    self.offerIdentifier = nil
    self.currencyCode = currencyCode
    self.price = stripeOffer.price
    self.paymentMode = paymentMode
    self.subscriptionPeriod = subscriptionPeriod
    self.numberOfPeriods = stripeOffer.periodCount
    self.type = .introductory
    self.localizedPriceString = stripeOffer.localizedPrice
  }
}

// MARK: - Private

private extension StoreProductDiscount.PaymentMode {
  init?(subscriptionOfferPaymentMode paymentMode: StripeProductType.SubscriptionIntroductoryOffer.PaymentMethod) {
    switch paymentMode {
    case .payUpFront:
      self = .payUpFront
    case .payAsYouGo:
      self = .payAsYouGo
    case .freeTrial:
      self = .freeTrial
    }
  }
}
