//
// Copyright RevenueCat Inc. All Rights Reserved.
//
// Licensed under the MIT License (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// opensource.org/licenses/MIT
//
// StoreProduct.swift
//
// Created by Andrés Boedo on 7/16/21.
// Updated by Yusuf Tör from Superwall on 11/8/22.
import Foundation
import StoreKit

/// TypeAlias to StoreKit 1's Product type, called `StoreKit/SKProduct`
public typealias SK1Product = SKProduct

/// TypeAlias to StoreKit 2's Product type, called `StoreKit.Product`
@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias SK2Product = StoreKit.Product

@objc(SWKStoreProduct)
@objcMembers
public final class StoreProduct: NSObject, StoreProductType {
  let product: StoreProductType

  /// Returns the `SKProduct` if this `StoreProduct` represents a `StoreKit.SKProduct`.
  public var sk1Product: SK1Product? {
    return (product as? SK1StoreProduct)?.underlyingSK1Product
  }

  /// Returns the `Product` if this `StoreProduct` represents a `StoreKit.Product`.
  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public var sk2Product: SK2Product? {
    return (product as? SK2StoreProduct)?.underlyingSK2Product
  }

  public var productIdentifier: String {
    product.productIdentifier
  }

  public var subscriptionGroupIdentifier: String? {
    return product.subscriptionGroupIdentifier
  }

  public var attributes: [String: String] {
    return [
      "rawPrice": "\(price)",
      "price": localizedPrice,
      "periodAlt": localizedSubscriptionPeriod,
      "localizedPeriod": localizedSubscriptionPeriod,
      "period": period,
      "periodly": "\(period)ly",
      "weeklyPrice": weeklyPrice,
      "dailyPrice": dailyPrice,
      "monthlyPrice": monthlyPrice,
      "yearlyPrice": yearlyPrice,
      "trialPeriodDays": trialPeriodDaysString,
      "trialPeriodWeeks": trialPeriodWeeksString,
      "trialPeriodMonths": trialPeriodMonthsString,
      "trialPeriodYears": trialPeriodYearsString,
      "trialPeriodText": trialPeriodText,
      "trialPeriodEndDate": trialPeriodEndDateString,
      "periodDays": periodDaysString,
      "periodWeeks": periodWeeksString,
      "periodMonths": periodMonthsString,
      "periodYears": periodYearsString,
      "locale": locale,
      "languageCode": languageCode ?? "n/a",
      "currencyCode": currencyCode ?? "n/a",
      "currencySymbol": currencySymbol ?? "n/a",
      "identifier": productIdentifier
    ]
  }

  var attributesJson: JSON {
    return JSON(attributes)
  }

  var swProductTemplateVariablesJson: JSON {
    product.swProductTemplateVariablesJson
  }

  var swProduct: SWProduct {
    product.swProduct
  }

  public var localizedPrice: String {
    product.localizedPrice
  }

  public var localizedSubscriptionPeriod: String {
    product.localizedSubscriptionPeriod
  }

  public var period: String {
    product.period
  }

  public var periodWeeks: Int {
    product.periodWeeks
  }

  public var periodWeeksString: String {
    product.periodWeeksString
  }

  public var periodMonths: Int {
    product.periodMonths
  }

  public var periodMonthsString: String {
    product.periodMonthsString
  }

  public var periodYears: Int {
    product.periodYears
  }

  public var periodYearsString: String {
    product.periodYearsString
  }

  public var periodDays: Int {
    product.periodDays
  }

  public var periodDaysString: String {
    product.periodDaysString
  }

  public var dailyPrice: String {
    product.dailyPrice
  }

  public var weeklyPrice: String {
    product.weeklyPrice
  }

  public var monthlyPrice: String {
    product.monthlyPrice
  }

  public var yearlyPrice: String {
    product.yearlyPrice
  }

  public var hasFreeTrial: Bool {
    product.hasFreeTrial
  }

  public var trialPeriodEndDate: Date? {
    product.trialPeriodEndDate
  }

  public var trialPeriodEndDateString: String {
    product.trialPeriodEndDateString
  }

  public var trialPeriodDays: Int {
    product.trialPeriodDays
  }

  public var trialPeriodDaysString: String {
    product.trialPeriodDaysString
  }

  public var trialPeriodWeeks: Int {
    product.trialPeriodWeeks
  }

  public var trialPeriodWeeksString: String {
    product.trialPeriodWeeksString
  }

  public var trialPeriodMonths: Int {
    product.trialPeriodMonths
  }

  public var trialPeriodMonthsString: String {
    product.trialPeriodMonthsString
  }

  public var trialPeriodYears: Int {
    product.trialPeriodYears
  }

  public var trialPeriodYearsString: String {
    product.trialPeriodYearsString
  }

  public var trialPeriodText: String {
    product.trialPeriodText
  }

  public var locale: String {
    product.locale
  }

  public var languageCode: String? {
    product.languageCode
  }

  public var currencyCode: String? {
    product.currencyCode
  }

  public var currencySymbol: String? {
    product.currencySymbol
  }

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 8.0, *)
  public var isFamilyShareable: Bool {
    product.isFamilyShareable
  }

  public var regionCode: String? {
    product.regionCode
  }

  public var price: Decimal {
    product.price
  }

  public var subscriptionPeriod: SubscriptionPeriod? {
    product.subscriptionPeriod
  }

  public var introductoryDiscount: StoreProductDiscount? {
    product.introductoryDiscount
  }

  public var discounts: [StoreProductDiscount] {
    product.discounts
  }

  public override func isEqual(_ object: Any?) -> Bool {
    return productIdentifier == (object as? StoreProductType)?.productIdentifier
  }

  /// Designated initializer.
  /// - SeeAlso: `StoreProduct/from(product:)` to wrap an instance of `StoreProduct`
  private init(_ product: StoreProductType) {
    self.product = product
  }

  public override var hash: Int {
    var hasher = Hasher()
    hasher.combine(productIdentifier)
    return hasher.finalize()
  }

  /// Creates an instance from any `StoreProductType`.
  /// If `product` is already a wrapped `StoreProduct` then this returns it instead.
  static func from(product: StoreProductType) -> StoreProduct {
    return product as? StoreProduct ?? StoreProduct(product)
  }

  public convenience init(sk1Product: SK1Product) {
    self.init(SK1StoreProduct(sk1Product: sk1Product))
  }

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  public convenience init(sk2Product: SK2Product) {
    self.init(SK2StoreProduct(sk2Product: sk2Product))
  }
}
