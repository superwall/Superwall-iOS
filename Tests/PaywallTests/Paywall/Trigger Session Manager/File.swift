//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2022.
//

import Foundation
import StoreKit

class MockSkProduct: SKProduct {
  let internalSubscriptionPeriod: SKProductSubscriptionPeriod?

  override var subscriptionPeriod: SKProductSubscriptionPeriod? {
    return internalSubscriptionPeriod
  }

  override var priceLocale: Locale {
    return .current
  }

  init(subscriptionPeriod: SKProductSubscriptionPeriod? = nil) {
    self.internalSubscriptionPeriod = subscriptionPeriod
  }
}
