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

  override var price: NSDecimalNumber {
    return 0
  }

  init(testSubscriptionPeriod: MockSubscriptionPeriod) {
    self.testSubscriptionPeriod = testSubscriptionPeriod
  }
}
