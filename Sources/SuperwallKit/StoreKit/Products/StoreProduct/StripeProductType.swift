//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 24/07/2025.
//
// swiftlint:disable type_body_length file_length

import Foundation
import StoreKit

struct StripeProductType: StoreProductType {
  let id: String
  let price: Decimal
  let localizedPrice: String
  let currencyCode: String?
  let currencySymbol: String?
  let priceLocale: PriceLocale
  let stripeSubscriptionPeriod: StripeSubscriptionPeriod?
  let subscriptionIntroOffer: SubscriptionIntroductoryOffer?
  let entitlements: Set<Entitlement>
  private var stripeLocale: Locale {
    Locale(identifier: priceLocale.identifier)
  }
  private let priceFormatterProvider = PriceFormatterProvider()

  struct PriceLocale: Equatable, Hashable {
    let identifier: String
    let languageCode: String
    let currencyCode: String
    let currencySymbol: String
  }

  struct StripeSubscriptionPeriod: Equatable, Hashable {
    let unit: Unit
    let value: Int

    enum Unit: String, Equatable, Decodable {
      case day
      case week
      case month
      case year
    }
  }

  struct SubscriptionIntroductoryOffer: Equatable, Hashable {
    let period: StripeSubscriptionPeriod
    let localizedPrice: String
    let price: Decimal
    let periodCount: Int

    enum PaymentMethod: String, Equatable, Decodable {
      case payAsYouGo
      case payUpFront
      case freeTrial
    }
    let paymentMethod: PaymentMethod
  }

  var productIdentifier: String {
    id
  }

  let subscriptionGroupIdentifier: String? = nil

  var swProduct: SWProduct {
    return SWProduct(product: self)
  }

  var priceFormatter: NumberFormatter? {
    guard let currencyCode = currencyCode else {
      return nil
    }
    return priceFormatterProvider.priceFormatterForSK2(
      withCurrencyCode: currencyCode,
      locale: stripeLocale
    )
  }

  private func priceFormatter(locale: Locale) -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.locale = stripeLocale
    formatter.numberStyle = .currency
    return formatter
  }

  var localizedSubscriptionPeriod: String {
    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return ""
    }

    let dateComponents: DateComponents

    switch subscriptionPeriod.unit {
    case .day: dateComponents = DateComponents(day: subscriptionPeriod.value)
    case .week: dateComponents = DateComponents(weekOfMonth: subscriptionPeriod.value)
    case .month: dateComponents = DateComponents(month: subscriptionPeriod.value)
    case .year: dateComponents = DateComponents(year: subscriptionPeriod.value)
    @unknown default:
      dateComponents = DateComponents(month: subscriptionPeriod.value)
    }

    return DateComponentsFormatter.localizedString(from: dateComponents, unitsStyle: .short) ?? ""
  }

  var period: String {
    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return ""
    }

    if subscriptionPeriod.unit == .day {
      if subscriptionPeriod.value == 7 {
        return "week"
      } else {
        return "day"
      }
    }

    if subscriptionPeriod.unit == .month {
      switch subscriptionPeriod.value {
      case 2:
        return "2 months"
      case 3:
        return "quarter"
      case 6:
        return "6 months"
      default:
        return "month"
      }
    }

    if subscriptionPeriod.unit == .week {
      return "week"
    }

    if subscriptionPeriod.unit == .year {
      return "year"
    }

    return ""
  }

  var periodly: String {
    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return ""
    }

    if subscriptionPeriod.unit == .month {
      switch subscriptionPeriod.value {
      case 2, 6:
        return "every \(period)"
      default:
        break
      }
    }

    return "\(period)ly"
  }

  var periodWeeks: Int {
    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return 0
    }

    let numberOfUnits = subscriptionPeriod.value

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

  var periodWeeksString: String {
    return "\(periodWeeks)"
  }

  var periodMonths: Int {
    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return 0
    }
    let numberOfUnits = subscriptionPeriod.value

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

  var periodMonthsString: String {
    return "\(periodMonths)"
  }

  var periodYears: Int {
    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return 0
    }
    let numberOfUnits = subscriptionPeriod.value

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

  var periodYearsString: String {
    return "\(periodYears)"
  }

  var periodDays: Int {
    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return 0
    }
    let numberOfUnits = subscriptionPeriod.value

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

  var periodDaysString: String {
    return "\(periodDays)"
  }

  var dailyPrice: String {
    if price == 0.00 {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = stripeLocale

    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return "n/a"
    }
    let numberOfUnits = subscriptionPeriod.value
    var periods: Decimal = 1.0
    let inputPrice = price

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

    return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "n/a"
  }

  var weeklyPrice: String {
    if price == 0.00 {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = stripeLocale

    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return "n/a"
    }
    let numberOfUnits = subscriptionPeriod.value
    var periods: Decimal = 1.0

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

    return numberFormatter.string(from: NSDecimalNumber(decimal: price / periods)) ?? "n/a"
  }

  var monthlyPrice: String {
    if price == 0.00 {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = stripeLocale

    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return "n/a"
    }

    let numberOfUnits = subscriptionPeriod.value
    var periods: Decimal = 1.0

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

    return numberFormatter.string(from: NSDecimalNumber(decimal: price / periods)) ?? "n/a"
  }

  var yearlyPrice: String {
    if price == 0.00 {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = stripeLocale

    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return "n/a"
    }

    let numberOfUnits = subscriptionPeriod.value
    var periods: Decimal = 1.0

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

    return numberFormatter.string(from: NSDecimalNumber(decimal: price / periods)) ?? "n/a"
  }

  var hasFreeTrial: Bool {
    return subscriptionIntroOffer != nil
  }

  var trialPeriodEndDate: Date? {
    guard let trialPeriod = subscriptionIntroOffer?.period else {
      return nil
    }
    let numberOfUnits = trialPeriod.value

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

  var trialPeriodEndDateString: String {
    if let trialPeriodEndDate = trialPeriodEndDate {
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .medium
      dateFormatter.timeStyle = .none
      dateFormatter.locale = .autoupdatingCurrent

      return dateFormatter.string(from: trialPeriodEndDate)
    }
    return ""
  }

  var trialPeriodDays: Int {
    guard let trialPeriod = subscriptionIntroOffer?.period else {
      return 0
    }

    let numberOfUnits = trialPeriod.value

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

  var trialPeriodDaysString: String {
    return "\(trialPeriodDays)"
  }

  var trialPeriodWeeks: Int {
    guard let trialPeriod = subscriptionIntroOffer?.period else {
      return 0
    }
    let numberOfUnits = trialPeriod.value

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

  var trialPeriodWeeksString: String {
    return "\(trialPeriodWeeks)"
  }

  var trialPeriodMonths: Int {
    guard let trialPeriod = subscriptionIntroOffer?.period else {
      return 0
    }
    let numberOfUnits = trialPeriod.value

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

  var trialPeriodMonthsString: String {
    return "\(trialPeriodMonths)"
  }

  var trialPeriodYears: Int {
    guard let trialPeriod = subscriptionIntroOffer?.period else {
      return 0
    }
    let numberOfUnits = trialPeriod.value

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

  var trialPeriodYearsString: String {
    return "\(trialPeriodYears)"
  }

  var trialPeriodText: String {
    guard let trialPeriod = subscriptionIntroOffer?.period else {
      return ""
    }

    let units = trialPeriod.value

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

  var locale: String {
    stripeLocale.identifier
  }

  var languageCode: String? {
    stripeLocale.languageCode
  }

  var regionCode: String? {
    stripeLocale.regionCode
  }

  let isFamilyShareable = false

  var subscriptionPeriod: SubscriptionPeriod? {
    guard let subscriptionPeriod = stripeSubscriptionPeriod else {
      return nil
    }
    return SubscriptionPeriod.from(stripeSubscriptionPeriod: subscriptionPeriod)
  }

  var introductoryDiscount: StoreProductDiscount? {
    subscriptionIntroOffer
      .flatMap { StoreProductDiscount(stripeOffer: $0, currencyCode: currencyCode) }
  }

  // We don't have any promotional offers.
  let discounts: [StoreProductDiscount] = []

  var trialPeriodPrice: Decimal {
    subscriptionIntroOffer?.price ?? 0.00
  }

  func trialPeriodPricePerUnit(_ unit: SubscriptionPeriod.Unit) -> String {
    guard let introductoryDiscount = introductoryDiscount else {
      return priceFormatter?.string(from: 0.00) ?? "$0.00"
    }
    if introductoryDiscount.price == 0.00 {
      return priceFormatter?.string(from: 0.00) ?? "$0.00"
    }

    let introMonthlyPrice = introductoryDiscount.pricePerUnit(unit)

    return priceFormatter?.string(from: NSDecimalNumber(decimal: introMonthlyPrice)) ?? "$0.00"
  }

  var localizedTrialPeriodPrice: String {
    guard let price = subscriptionIntroOffer?.price else {
      return priceFormatter?.string(from: 0.00) ?? "$0.00"
    }
    return priceFormatter?.string(from: price as NSDecimalNumber) ?? "$0.00"
  }
}

// MARK: - Hashable
@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension StripeProductType: Hashable {
  static func == (lhs: StripeProductType, rhs: StripeProductType) -> Bool {
    return lhs.entitlements == rhs.entitlements
      && lhs.id == rhs.id
      && lhs.price == rhs.price
      && lhs.localizedPrice == rhs.localizedPrice
      && lhs.currencyCode == rhs.currencyCode
      && lhs.currencySymbol == rhs.currencySymbol
      && lhs.priceLocale == rhs.priceLocale
      && lhs.subscriptionPeriod == rhs.subscriptionPeriod
      && lhs.subscriptionIntroOffer == rhs.subscriptionIntroOffer
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(entitlements)
    hasher.combine(id)
    hasher.combine(price)
    hasher.combine(localizedPrice)
    hasher.combine(currencyCode)
    hasher.combine(currencySymbol)
    hasher.combine(priceLocale)
    hasher.combine(subscriptionPeriod)
    hasher.combine(subscriptionIntroOffer)
  }
}
