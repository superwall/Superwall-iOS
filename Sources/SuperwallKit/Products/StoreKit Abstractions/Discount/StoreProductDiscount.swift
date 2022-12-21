//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  StoreProductDiscount.swift
//
//  Created by Joshua Liebowitz on 7/2/21.
//  Updated by Yusuf Tör from Superwall on 11/8/22.

import StoreKit

/// TypeAlias to StoreKit 1's Discount type, called `SKProductDiscount`
public typealias SK1ProductDiscount = SKProductDiscount

/// TypeAlias to StoreKit 2's Discount type, called `StoreKit.Product.SubscriptionOffer`
@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias SK2ProductDiscount = StoreKit.Product.SubscriptionOffer

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
  }

  private let discount: StoreProductDiscountType

  init(_ discount: StoreProductDiscountType) {
    self.discount = discount
  }

  public var offerIdentifier: String? { self.discount.offerIdentifier }
  public var currencyCode: String? { self.discount.currencyCode }
  @nonobjc public var price: Decimal { self.discount.price }
  public var localizedPriceString: String { self.discount.localizedPriceString }
  public var paymentMode: PaymentMode { self.discount.paymentMode }
  public var subscriptionPeriod: SubscriptionPeriod { self.discount.subscriptionPeriod }
  public var numberOfPeriods: Int { self.discount.numberOfPeriods }
  public var type: DiscountType { self.discount.type }

  /// Creates an instance from any `StoreProductDiscountType`.
  /// If `discount` is already a wrapped `StoreProductDiscount` then this returns it instead.
  static func from(discount: StoreProductDiscountType) -> StoreProductDiscount {
      return discount as? StoreProductDiscount
      ?? StoreProductDiscount(discount)
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? StoreProductDiscountType else { return false }

    return Data(discount: self) == Data(discount: other)
  }

  public override var hash: Int {
    return id.hashValue
  }
}

extension StoreProductDiscount {
  /// The discount price of the product in the local currency.
  /// - Note: this is meant for  Objective-C. For Swift, use ``price`` instead.
  @objc(price)
  public var priceDecimalNumber: NSDecimalNumber {
      return self.price as NSDecimalNumber
  }
}

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

/// The details of an introductory offer or a promotional offer for an auto-renewable subscription.
protocol StoreProductDiscountType {
  /// A string used to uniquely identify a discount offer for a product.
  var offerIdentifier: String? { get }

  /// The currency of the product's price.
  var currencyCode: String? { get }

  /// The discount price of the product in the local currency.
  var price: Decimal { get }

  /// The price of this product discount formatted for locale.
  var localizedPriceString: String { get }

  /// The payment mode for this product discount.
  var paymentMode: StoreProductDiscount.PaymentMode { get }

  /// The period for the product discount.
  var subscriptionPeriod: SubscriptionPeriod { get }

  /// The number of periods the product discount is available.
  /// This is `1` for ``StoreProductDiscount/PaymentMode-swift.enum/payUpFront``
  /// and ``StoreProductDiscount/PaymentMode-swift.enum/freeTrial``, but can be
  /// more than 1 for ``StoreProductDiscount/PaymentMode-swift.enum/payAsYouGo``.
  ///
  /// - Note:
  /// A product discount may be available for one or more periods.
  /// The period, defined in `subscriptionPeriod`, is a set number of days, weeks, months, or years.
  /// The total length of time that a product discount is available is calculated by
  /// multiplying the `numberOfPeriods` by the period.
  /// Note that the discount period is independent of the product subscription period.
  var numberOfPeriods: Int { get }

  /// The type of product discount.
  var type: StoreProductDiscount.DiscountType { get }
}

// MARK: - Wrapper constructors / getters

extension StoreProductDiscount {
  convenience init?(sk1Discount: SK1ProductDiscount) {
    guard let discount = SK1StoreProductDiscount(sk1Discount: sk1Discount) else {
      return nil
    }
    self.init(discount)
  }

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  convenience init?(sk2Discount: SK2ProductDiscount, currencyCode: String?) {
    guard
      let discount = SK2StoreProductDiscount(
        sk2Discount: sk2Discount,
        currencyCode: currencyCode
      )
    else {
      return nil
    }
    self.init(discount)
  }

  /// Returns the `SK1ProductDiscount` if this `StoreProductDiscount` represents a `SKProductDiscount`.
  public var sk1Discount: SK1ProductDiscount? {
    return (self.discount as? SK1StoreProductDiscount)?.underlyingSK1Discount
  }

  /// Returns the `SK2ProductDiscount` if this `StoreProductDiscount` represents a `Product.SubscriptionOffer`.
  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public var sk2Discount: SK2ProductDiscount? {
    return (self.discount as? SK2StoreProductDiscount)?.underlyingSK2Discount
  }
}

extension StoreProductDiscount.DiscountType {
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

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  static func from(sk2Discount: SK2ProductDiscount) -> Self? {
    switch sk2Discount.type {
    case SK2ProductDiscount.OfferType.introductory:
      return .introductory
    case SK2ProductDiscount.OfferType.promotional:
      return .promotional
    default:
      return nil
    }
  }
}

extension StoreProductDiscount: Identifiable {
  /// The stable identity of the entity associated with this instance.
  public var id: Data { return Data(discount: self) }
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
