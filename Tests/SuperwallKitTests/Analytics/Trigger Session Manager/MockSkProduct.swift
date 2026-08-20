//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2022.
//

import Foundation
import StoreKit

final class MockSkProduct: SKProduct {
  private let internalPrice: NSDecimalNumber?
  private let internalIntroPeriod: MockIntroductoryPeriod?
  private let internalSubscriptionPeriod: SKProductSubscriptionPeriod?
  private let internalProductIdentifier: String?
  private let internalSubscriptionGroupIdentifier: String?
  private let internalLocalizedTitle: String?

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
    return internalPrice ?? 0
  }

  @available(iOS 12.0, *)
  override var subscriptionGroupIdentifier: String? {
    return internalSubscriptionGroupIdentifier ?? super.subscriptionGroupIdentifier
  }

  /// Not chained to `super.localizedTitle`, unlike the other overrides: the underlying
  /// `SKProduct` backing store is never populated for a synthetic instance like this one, and
  /// (unlike the optional properties above) a crash reading that unset non-optional String isn't
  /// worth risking just to reproduce "no title" — defaulting straight to `""` gets the same
  /// observable result safely.
  override var localizedTitle: String {
    return internalLocalizedTitle ?? ""
  }

  init(
    subscriptionPeriod: SKProductSubscriptionPeriod? = nil,
    productIdentifier: String? = nil,
    introPeriod: MockIntroductoryPeriod? = nil,
    subscriptionGroupIdentifier: String? = nil,
    price: NSDecimalNumber? = nil,
    localizedTitle: String? = nil
  ) {
    self.internalSubscriptionPeriod = subscriptionPeriod
    self.internalProductIdentifier = productIdentifier
    self.internalIntroPeriod = introPeriod
    self.internalSubscriptionGroupIdentifier = subscriptionGroupIdentifier
    self.internalPrice = price
    self.internalLocalizedTitle = localizedTitle
  }
}
