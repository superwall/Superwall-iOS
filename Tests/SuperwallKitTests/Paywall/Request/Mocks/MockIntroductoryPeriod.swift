//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/03/2022.
//

import StoreKit

final class MockIntroductoryPeriod: SKProductDiscount {
  var testSubscriptionPeriod: MockSubscriptionPeriod

  override var subscriptionPeriod: SKProductSubscriptionPeriod {
    return testSubscriptionPeriod
  }

  override var priceLocale: Locale {
    return .current
  }

  init(testSubscriptionPeriod: MockSubscriptionPeriod) {
    self.testSubscriptionPeriod = testSubscriptionPeriod
  }
}

extension SKProduct {
  /// To be used for mocking only.
  convenience init(
    identifier: String,
    price: String,
    introductoryPrice: MockIntroductoryPeriod? = nil,
    priceLocale: Locale = .current
  ) {
    self.init()
    setValue(identifier, forKey: "productIdentifier")
    setValue(NSDecimalNumber(string: price), forKey: "price")
    setValue(priceLocale, forKey: "priceLocale")
    setValue(introductoryPrice, forKey: "introductoryPrice")
  }
}
