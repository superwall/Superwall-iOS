//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  SK1StoreProductDiscount.swift
//
//  Created by Nacho Soto on 1/17/22.
//  Updated by Yusuf Tör from Superwall on 11/8/22.
// swiftlint:disable strict_fileprivate

import StoreKit

/// TypeAlias to StoreKit 1's Discount type, called `SKProductDiscount`
public typealias SK1ProductDiscount = SKProductDiscount

/// Type that wraps `StoreKit.Product.SubscriptionOffer` and `SKProductDiscount`
/// and provides access to their properties.
/// Information about a subscription offer that you configured in App Store Connect.
@objc(SWKStoreProductDiscount)
@objcMembers
public final class StoreProductDiscount: NSObject, StoreProductDiscountType {
  /// The payment mode for a `StoreProductDiscount`
  /// Indicates how the product discount price is charged.
  @objc(SWKPaymentMode)
  public enum PaymentMode: Int {
    /// Price is charged one or more times
    case payAsYouGo = 0
    /// Price is charged once in advance
    case payUpFront = 1
    /// No initial charge
    case freeTrial = 2

    init?(skProductDiscountPaymentMode paymentMode: SKProductDiscount.PaymentMode) {
      switch paymentMode {
      case .payUpFront:
        self = .payUpFront
      case .payAsYouGo:
        self = .payAsYouGo
      case .freeTrial:
        self = .freeTrial
      @unknown default:
        return nil
      }
    }
  }

  /// The discount type for a `StoreProductDiscount`
  /// Wraps `SKProductDiscount.Type` if this `StoreProductDiscount` represents a `SKProductDiscount`.
  /// Wraps  `Product.SubscriptionOffer.OfferType` if this `StoreProductDiscount` represents
  /// a `Product.SubscriptionOffer`.
  @objc(SWKDiscountType)
  public enum DiscountType: Int, Codable {
    /// Introductory offer
    case introductory = 0
    /// Promotional offer for subscriptions
    case promotional = 1

    static func from(sk1Discount: SK1ProductDiscount) -> Self? {
      switch sk1Discount.type {
      case .introductory:
        return .introductory
      case .subscription:
        return .promotional
      @unknown default:
        return nil
      }
    }
  }

  public let underlyingSK1Discount: SK1ProductDiscount
  public let offerIdentifier: String?
  public let currencyCode: String?
  public let price: Decimal
  public let paymentMode: PaymentMode
  public let subscriptionPeriod: SubscriptionPeriod
  public let numberOfPeriods: Int
  public let type: DiscountType

  public var localizedPriceString: String {
    return self.priceFormatter.string(from: self.underlyingSK1Discount.price) ?? ""
  }

  private let priceFormatterProvider = PriceFormatterProvider()

  private var priceFormatter: NumberFormatter {
    return self.priceFormatterProvider.priceFormatterForSK1(
      with: self.underlyingSK1Discount.optionalLocale ?? .current
    )
  }

  init?(sk1Discount: SK1ProductDiscount) {
    guard
      let paymentMode = PaymentMode(skProductDiscountPaymentMode: sk1Discount.paymentMode),
      let subscriptionPeriod = SubscriptionPeriod.from(sk1SubscriptionPeriod: sk1Discount.subscriptionPeriod),
      let type = DiscountType.from(sk1Discount: sk1Discount)
    else {
      return nil
    }

    self.underlyingSK1Discount = sk1Discount

    self.offerIdentifier = sk1Discount.identifier
    self.currencyCode = sk1Discount.optionalLocale?.currencyCode
    self.price = sk1Discount.price as Decimal
    self.paymentMode = paymentMode
    self.subscriptionPeriod = subscriptionPeriod
    self.numberOfPeriods = sk1Discount.numberOfPeriods
    self.type = type
  }

  // MARK: - Hashable
  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? StoreProductDiscountType else { return false }

    return Data(discount: self) == Data(discount: other)
  }

  public override var hash: Int {
    return id.hashValue
  }
}

// MARK: - Identifiable
extension StoreProductDiscount: Identifiable {
  /// The stable identity of the entity associated with this instance.
  public var id: Data { return Data(discount: self) }
}

// MARK: - Private

extension StoreProductDiscount {
  /// Used to represent `StoreProductDiscount/id`.
  public struct Data: Hashable {
    private var offerIdentifier: String?
    private var currencyCode: String?
    private var price: Decimal
    private var localizedPriceString: String
    private var paymentMode: StoreProductDiscount.PaymentMode
    private var subscriptionPeriod: SubscriptionPeriod
    private var numberOfPeriods: Int
    private var type: StoreProductDiscount.DiscountType

    fileprivate init(discount: StoreProductDiscountType) {
      self.offerIdentifier = discount.offerIdentifier
      self.currencyCode = discount.currencyCode
      self.price = discount.price
      self.localizedPriceString = discount.localizedPriceString
      self.paymentMode = discount.paymentMode
      self.subscriptionPeriod = discount.subscriptionPeriod
      self.numberOfPeriods = discount.numberOfPeriods
      self.type = discount.type
    }
  }
}

extension SK1ProductDiscount {
  // See https://github.com/RevenueCat/purchases-ios/issues/1521
  // Despite `SKProductDiscount.priceLocale` being non-optional, StoreKit might return `nil` `NSLocale`s.
  // This works around that to make sure the SDK doesn't crash when bridging to `Locale`.
  var optionalLocale: Locale? {
    guard let locale = priceLocale as NSLocale? else {
      return nil
    }

    return locale as Locale
  }
}
