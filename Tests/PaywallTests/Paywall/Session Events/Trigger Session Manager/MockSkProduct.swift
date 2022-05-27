//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2022.
//

import Foundation
import StoreKit

final class MockSkProduct: SKProduct {
  private let internalIntroPeriod: MockIntroductoryPeriod?
  private let internalSubscriptionPeriod: SKProductSubscriptionPeriod?
  private let internalProductIdentifier: String?

  override var productIdentifier: String {
    return internalProductIdentifier ?? super.productIdentifier
  }
  override var subscriptionPeriod: SKProductSubscriptionPeriod? {
    return internalSubscriptionPeriod ?? super.subscriptionPeriod
  }
  override var introductoryPrice: SKProductDiscount? {
    return internalIntroPeriod ?? super.introductoryPrice
  }

  override var priceLocale: Locale {
    return .current
  }

  override var price: NSDecimalNumber {
    return 0
  }

  init(
    subscriptionPeriod: SKProductSubscriptionPeriod? = nil,
    productIdentifier: String? = nil,
    introPeriod: MockIntroductoryPeriod? = nil
  ) {
    self.internalSubscriptionPeriod = subscriptionPeriod
    self.internalProductIdentifier = productIdentifier
    self.internalIntroPeriod = introPeriod
  }
}
