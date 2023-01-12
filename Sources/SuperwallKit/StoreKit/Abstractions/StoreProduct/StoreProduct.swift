//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  SK1StoreProduct.swift
//
//  Created by Nacho Soto on 12/20/21.
//  Updated by Yusuf Tör from Superwall on 11/8/22.
// swiftlint:disable type_body_length file_length

import Foundation
import StoreKit

/// TypeAlias to StoreKit 1's Product type, called `StoreKit/SKProduct`
public typealias SK1Product = SKProduct

/// A wrapper for SKProduct that contains properties specific to Superwall.
@objc(SWKStoreProduct)
@objcMembers
public final class StoreProduct: NSObject, StoreProductType {
  private let priceFormatterProvider = PriceFormatterProvider()
  public let underlyingSK1Product: SK1Product

  public var productIdentifier: String {
    return underlyingSK1Product.productIdentifier
  }

  public var subscriptionGroupIdentifier: String? {
    underlyingSK1Product.subscriptionGroupIdentifier
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
    return JSON(SWProductTemplateVariable(product: underlyingSK1Product).dictionary() as Any)
  }

  var swProduct: SWProduct {
    return SWProduct(product: underlyingSK1Product)
  }

  public var price: Decimal {
    underlyingSK1Product.price as Decimal
  }

  public var localizedPrice: String {
    return priceFormatter?.string(from: underlyingSK1Product.price) ?? ""
  }

  private var priceFormatter: NumberFormatter? {
    priceFormatterProvider.priceFormatterForSK1(with: underlyingSK1Product.priceLocale)
  }

  public var localizedSubscriptionPeriod: String {
    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return ""
    }

    let dateComponents: DateComponents

    switch subscriptionPeriod.unit {
    case .day: dateComponents = DateComponents(day: subscriptionPeriod.numberOfUnits)
    case .week: dateComponents = DateComponents(weekOfMonth: subscriptionPeriod.numberOfUnits)
    case .month: dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
    case .year: dateComponents = DateComponents(year: subscriptionPeriod.numberOfUnits)
    @unknown default:
      dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
    }

    return DateComponentsFormatter.localizedString(from: dateComponents, unitsStyle: .short) ?? ""
  }

  public var period: String {
    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return ""
    }

    if subscriptionPeriod.unit == .day {
      if subscriptionPeriod.numberOfUnits == 7 {
        return "week"
      } else {
        return "day"
      }
    }

    if subscriptionPeriod.unit == .month {
      return "month"
    }

    if subscriptionPeriod.unit == .week {
      return "week"
    }

    if subscriptionPeriod.unit == .year {
      return "year"
    }

    return ""
  }

  public var periodWeeks: Int {
    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return 0
    }

    let numberOfUnits = subscriptionPeriod.numberOfUnits

    if subscriptionPeriod.unit == .day {
      return (1 * numberOfUnits) / 7
    }

    if subscriptionPeriod.unit == .week {
      return numberOfUnits
    }

    if subscriptionPeriod.unit == .month {
      return 4 * numberOfUnits
    }

    if subscriptionPeriod.unit == .year {
      return 52 * numberOfUnits
    }

    return 0
  }

  public var periodWeeksString: String {
    return "\(periodWeeks)"
  }

  public var periodMonths: Int {
    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return 0
    }
    let numberOfUnits = subscriptionPeriod.numberOfUnits

    if subscriptionPeriod.unit == .day {
      return (1 * numberOfUnits) / 30
    }

    if subscriptionPeriod.unit == .week {
      return numberOfUnits / 4
    }

    if subscriptionPeriod.unit == .month {
      return numberOfUnits
    }

    if subscriptionPeriod.unit == .year {
      return 12 * numberOfUnits
    }

    return 0
  }

  public var periodMonthsString: String {
    return "\(periodMonths)"
  }

  public var periodYears: Int {
    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return 0
    }
    let numberOfUnits = subscriptionPeriod.numberOfUnits

    if subscriptionPeriod.unit == .day {
      return numberOfUnits / 365
    }

    if subscriptionPeriod.unit == .week {
      return numberOfUnits / 52
    }

    if subscriptionPeriod.unit == .month {
      return numberOfUnits / 12
    }

    if subscriptionPeriod.unit == .year {
      return numberOfUnits
    }

    return 0
  }

  public var periodYearsString: String {
    return "\(periodYears)"
  }

  public var periodDays: Int {
    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return 0
    }
    let numberOfUnits = subscriptionPeriod.numberOfUnits

    if subscriptionPeriod.unit == .day {
      return numberOfUnits
    }

    if subscriptionPeriod.unit == .week {
      return 7 * numberOfUnits
    }

    if subscriptionPeriod.unit == .month {
      return 30 * numberOfUnits
    }

    if subscriptionPeriod.unit == .year {
      return 365 * numberOfUnits
    }

    return 0
  }

  public var periodDaysString: String {
    return "\(periodDays)"
  }

  public var dailyPrice: String {
    if underlyingSK1Product.price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return "n/a"
    }
    let numberOfUnits = subscriptionPeriod.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = underlyingSK1Product.price as Decimal

    if subscriptionPeriod.unit == .year {
      periods = Decimal(365 * numberOfUnits)
    }

    if subscriptionPeriod.unit == .month {
      periods = Decimal(30 * numberOfUnits)
    }

    if subscriptionPeriod.unit == .week {
      periods = Decimal(numberOfUnits) / Decimal(7)
    }

    if subscriptionPeriod.unit == .day {
      periods = Decimal(numberOfUnits) / Decimal(1)
    }

    return priceFormatter?.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  public var weeklyPrice: String {
    if underlyingSK1Product.price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return "n/a"
    }
    let numberOfUnits = subscriptionPeriod.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = underlyingSK1Product.price as Decimal

    if subscriptionPeriod.unit == .year {
      periods = Decimal(52 * numberOfUnits)
    }

    if subscriptionPeriod.unit == .month {
      periods = Decimal(4 * numberOfUnits)
    }

    if subscriptionPeriod.unit == .week {
      periods = Decimal(numberOfUnits) / Decimal(1)
    }

    if subscriptionPeriod.unit == .day {
      periods = Decimal(numberOfUnits) / Decimal(7)
    }

    return priceFormatter?.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  public var monthlyPrice: String {
    if underlyingSK1Product.price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return "n/a"
    }

    let numberOfUnits = subscriptionPeriod.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = underlyingSK1Product.price as Decimal

    if subscriptionPeriod.unit == .year {
      periods = Decimal(12 * numberOfUnits)
    }

    if subscriptionPeriod.unit == .month {
      periods = Decimal(1 * numberOfUnits)
    }

    if subscriptionPeriod.unit == .week {
      periods = Decimal(numberOfUnits) / Decimal(4)
    }

    if subscriptionPeriod.unit == .day {
      periods = Decimal(numberOfUnits) / Decimal(30)
    }

    return priceFormatter?.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  public var yearlyPrice: String {
    if underlyingSK1Product.price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    guard let subscriptionPeriod = underlyingSK1Product.subscriptionPeriod else {
      return "n/a"
    }

    let numberOfUnits = subscriptionPeriod.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = underlyingSK1Product.price as Decimal

    if subscriptionPeriod.unit == .year {
      periods = Decimal(numberOfUnits)
    }

    if subscriptionPeriod.unit == .month {
      periods = Decimal(numberOfUnits) / Decimal(12)
    }

    if subscriptionPeriod.unit == .week {
      periods = Decimal(numberOfUnits) / Decimal(52)
    }

    if subscriptionPeriod.unit == .day {
      periods = Decimal(numberOfUnits) / Decimal(365)
    }

    return priceFormatter?.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  public var hasFreeTrial: Bool {
    return underlyingSK1Product.introductoryPrice != nil
  }

  public var trialPeriodEndDate: Date? {
    guard let trialPeriod = underlyingSK1Product.introductoryPrice?.subscriptionPeriod else {
      return nil
    }
    let numberOfUnits = trialPeriod.numberOfUnits

    let currentDate = Date()
    var dateComponent = DateComponents()

    switch trialPeriod.unit {
    case .day:
      dateComponent.day = numberOfUnits
    case .week:
      dateComponent.day = 7 * numberOfUnits
    case .month:
      dateComponent.month = numberOfUnits
    case .year:
      dateComponent.year = numberOfUnits
    @unknown default:
      return nil
    }

    guard let futureDate = Calendar.current.date(
      byAdding: dateComponent,
      to: currentDate
    ) else {
      return nil
    }

    return futureDate
  }

  public var trialPeriodEndDateString: String {
    if let trialPeriodEndDate = trialPeriodEndDate {
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .medium
      dateFormatter.timeStyle = .none
      dateFormatter.locale = .autoupdatingCurrent

      return dateFormatter.string(from: trialPeriodEndDate)
    }
    return ""
  }

  public var trialPeriodDays: Int {
    guard let trialPeriod = underlyingSK1Product.introductoryPrice?.subscriptionPeriod else {
      return 0
    }

    let numberOfUnits = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return Int(1 * numberOfUnits)
    }

    if trialPeriod.unit == .month {
      return Int(30 * numberOfUnits)
    }

    if trialPeriod.unit == .week {
      return Int(7 * numberOfUnits)
    }

    if trialPeriod.unit == .year {
      return Int(365 * numberOfUnits)
    }

    return 0
  }

  public var trialPeriodDaysString: String {
    return "\(trialPeriodDays)"
  }

  public var trialPeriodWeeks: Int {
    guard let trialPeriod = underlyingSK1Product.introductoryPrice?.subscriptionPeriod else {
      return 0
    }
    let numberOfUnits = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return Int(numberOfUnits / 7)
    }

    if trialPeriod.unit == .month {
      return 4 * numberOfUnits
    }

    if trialPeriod.unit == .week {
      return 1 * numberOfUnits
    }

    if trialPeriod.unit == .year {
      return 52 * numberOfUnits
    }

    return 0
  }

  public var trialPeriodWeeksString: String {
    return "\(trialPeriodWeeks)"
  }

  public var trialPeriodMonths: Int {
    guard let trialPeriod = underlyingSK1Product.introductoryPrice?.subscriptionPeriod else {
      return 0
    }
    let numberOfUnits = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return Int(numberOfUnits / 30)
    }

    if trialPeriod.unit == .month {
      return numberOfUnits * 1
    }

    if trialPeriod.unit == .week {
      return Int(numberOfUnits / 4)
    }

    if trialPeriod.unit == .year {
      return numberOfUnits * 12
    }

    return 0
  }

  public var trialPeriodMonthsString: String {
    return "\(trialPeriodMonths)"
  }

  public var trialPeriodYears: Int {
    guard let trialPeriod = underlyingSK1Product.introductoryPrice?.subscriptionPeriod else {
      return 0
    }
    let numberOfUnits = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return Int(numberOfUnits / 365)
    }

    if trialPeriod.unit == .month {
      return Int(numberOfUnits / 12)
    }

    if trialPeriod.unit == .week {
      return Int(numberOfUnits / 52)
    }

    if trialPeriod.unit == .year {
      return numberOfUnits
    }

    return 0
  }

  public var trialPeriodYearsString: String {
    return "\(trialPeriodYears)"
  }

  public var trialPeriodText: String {
    guard let trialPeriod = underlyingSK1Product.introductoryPrice?.subscriptionPeriod else {
      return ""
    }

    let units = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return "\(units)-day"
    }

    if trialPeriod.unit == .month {
      return "\(units * 30)-day"
    }

    if trialPeriod.unit == .week {
      return "\(units * 7)-day"
    }

    if trialPeriod.unit == .year {
      return "\(units * 365)-day"
    }

    return ""
  }

  public var locale: String {
    underlyingSK1Product.priceLocale.identifier
  }

  public var languageCode: String? {
    underlyingSK1Product.priceLocale.languageCode
  }

  public var currencyCode: String? {
    underlyingSK1Product.priceLocale.currencyCode
  }

  public var currencySymbol: String? {
    underlyingSK1Product.priceLocale.currencySymbol
  }

  public var regionCode: String? {
    underlyingSK1Product.priceLocale.regionCode
  }

  public var subscriptionPeriod: SubscriptionPeriod? {
    guard
      let skSubscriptionPeriod = underlyingSK1Product.subscriptionPeriod,
      skSubscriptionPeriod.numberOfUnits > 0
    else {
      return nil
    }
    return SubscriptionPeriod.from(sk1SubscriptionPeriod: skSubscriptionPeriod)
  }

  var introductoryDiscount: StoreProductDiscount? {
    return self.underlyingSK1Product.introductoryPrice
      .flatMap(StoreProductDiscount.init)
  }

  var discounts: [StoreProductDiscount] {
    return self.underlyingSK1Product.discounts
      .compactMap(StoreProductDiscount.init)
  }

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 8.0, *)
  var isFamilyShareable: Bool {
    underlyingSK1Product.isFamilyShareable
  }


  // MARK: - Hashable
  public override func isEqual(_ object: Any?) -> Bool {
    return productIdentifier == (object as? StoreProductType)?.productIdentifier
  }

  public override var hash: Int {
    var hasher = Hasher()
    hasher.combine(productIdentifier)
    return hasher.finalize()
  }

  init(sk1Product: SK1Product) {
    self.underlyingSK1Product = sk1Product
  }
}
