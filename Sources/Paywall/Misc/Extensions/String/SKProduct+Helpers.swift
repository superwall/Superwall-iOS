//
//  SKProduct+Helpers.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import StoreKit

extension SKProduct {
  var legacyEventData: [String: String] {
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
      "trialPeriodDays": trialPeriodDays,
      "trialPeriodWeeks": trialPeriodWeeks,
      "trialPeriodMonths": trialPeriodMonths,
      "trialPeriodYears": trialPeriodYears,
      "trialPeriodText": trialPeriodText,
      "periodDays": periodDays,
      "periodWeeks": periodWeeks,
      "periodMonths": periodMonths,
      "periodYears": periodYears,
      "locale": priceLocale.identifier,
      "languageCode": priceLocale.languageCode ?? "n/a",
      "currencyCode": priceLocale.currencyCode ?? "n/a",
      "currencySymbol": priceLocale.currencySymbol ?? "n/a",
      "identifier": productIdentifier
    ]
  }

  var eventData: JSON {
    return JSON(legacyEventData)
  }

  var productVariables: JSON {
    return JSON(SWTemplateVariable(product: self).dictionary as Any)
  }

  var swProduct: SWProduct {
    return SWProduct(product: self)
  }

  // new schema

  var localizedPrice: String {
    return priceFormatter(locale: priceLocale).string(from: price) ?? "?"
  }

  private func priceFormatter(locale: Locale) -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.locale = priceLocale
    formatter.numberStyle = .currency
    return formatter
  }

  var localizedSubscriptionPeriod: String {
    guard let subscriptionPeriod = self.subscriptionPeriod else {
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

  var period: String {
    guard let period = subscriptionPeriod
    else {
      return ""
    }

    if period.unit == .day {
      if period.numberOfUnits == 7 {
        return "week"
      } else {
        return "day"
      }
    }

    if period.unit == .month {
      return "month"
    }

    if period.unit == .week {
      return "week"
    }

    if period.unit == .year {
      return "year"
    }

    return ""
  }

  var periodWeeks: String {
    guard let period = subscriptionPeriod else {
      return ""
    }

    let numberOfUnits = period.numberOfUnits

    if period.unit == .day {
      return "\(Int((1 * numberOfUnits) / 7))"
    }

    if period.unit == .week {
      return "\(Int(numberOfUnits))"
    }

    if period.unit == .month {
      return "\(Int(4 * numberOfUnits))"
    }

    if period.unit == .year {
      return "\(Int(52 * numberOfUnits))"
    }

    return "0"
  }

  var periodMonths: String {
    guard let period = subscriptionPeriod else {
      return ""
    }
    let numberOfUnits = period.numberOfUnits

    if period.unit == .day {
      return "\(Int((1 * numberOfUnits) / 30))"
    }

    if period.unit == .week {
      return "\(Int(numberOfUnits / 4))"
    }

    if period.unit == .month {
      return "\(Int(numberOfUnits))"
    }

    if period.unit == .year {
      return "\(Int(12 * numberOfUnits))"
    }

    return "0"
  }

  var periodYears: String {
    guard let period = subscriptionPeriod else {
      return ""
    }
    let numberOfUnits = period.numberOfUnits

    if period.unit == .day {
      return "\(Int(numberOfUnits / 365))"
    }

    if period.unit == .week {
      return "\(Int(numberOfUnits / 52))"
    }

    if period.unit == .month {
      return "\(Int(numberOfUnits / 12))"
    }

    if period.unit == .year {
      return "\(Int(numberOfUnits))"
    }

    return "0"
  }

  var periodDays: String {
    guard let period = subscriptionPeriod else {
      return ""
    }
    let numberOfUnits = period.numberOfUnits

    if period.unit == .day {
      return "\(Int(1 * numberOfUnits))"
    }

    if period.unit == .week {
      return "\(Int(7 * numberOfUnits))"
    }

    if period.unit == .month {
      return "\(Int(30 * numberOfUnits))"
    }

    if period.unit == .year {
      return "\(Int(365 * numberOfUnits))"
    }

    return "0"
  }

  var dailyPrice: String {
    if price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    let locale = priceLocale
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = locale

    guard let period = subscriptionPeriod else {
      return "n/a"
    }
    let numberOfUnits = period.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = price as Decimal

    if period.unit == .year {
      periods = Decimal(365 * numberOfUnits)
    }

    if period.unit == .month {
      periods = Decimal(30 * numberOfUnits)
    }

    if period.unit == .week {
      periods = Decimal(numberOfUnits) / Decimal(7)
    }

    if period.unit == .day {
      periods = Decimal(numberOfUnits) / Decimal(1)
    }

    return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  var weeklyPrice: String {
    if price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    let locale = priceLocale
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = locale

    guard let period = subscriptionPeriod else {
      return "n/a"
    }
    let numberOfUnits = period.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = price as Decimal

    if period.unit == .year {
      periods = Decimal(52 * numberOfUnits)
    }

    if period.unit == .month {
      periods = Decimal(4 * numberOfUnits)
    }

    if period.unit == .week {
      periods = Decimal(numberOfUnits) / Decimal(1)
    }

    if period.unit == .day {
      periods = Decimal(numberOfUnits) / Decimal(7)
    }

    return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  var monthlyPrice: String {
    if price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    let locale = priceLocale
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = locale

    guard let period = subscriptionPeriod else {
      return "n/a"
    }

    let numberOfUnits = period.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = price as Decimal

    if period.unit == .year {
      periods = Decimal(12 * numberOfUnits)
    }

    if period.unit == .month {
      periods = Decimal(1 * numberOfUnits)
    }

    if period.unit == .week {
      periods = Decimal(numberOfUnits) / Decimal(4)
    }

    if period.unit == .day {
      periods = Decimal(numberOfUnits) / Decimal(30)
    }

    return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  var yearlyPrice: String {
    if price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    let locale = priceLocale
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = locale

    guard let period = subscriptionPeriod else {
      return "n/a"
    }

    let numberOfUnits = period.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = price as Decimal

    if period.unit == .year {
      periods = Decimal(numberOfUnits)
    }

    if period.unit == .month {
      periods = Decimal(numberOfUnits) / Decimal(12)
    }

    if period.unit == .week {
      periods = Decimal(numberOfUnits) / Decimal(52)
    }

    if period.unit == .day {
      periods = Decimal(numberOfUnits) / Decimal(365)
    }

    return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  var hasFreeTrial: Bool {
    if introductoryPrice?.subscriptionPeriod != nil {
      return true
    } else {
      return false
    }
  }

  var trialPeriodDays: String {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
      return "0"
    }

    let numberOfUnits = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return "\(Int(1 * numberOfUnits))"
    }

    if trialPeriod.unit == .month {
      return "\(Int(30 * numberOfUnits))"
    }

    if trialPeriod.unit == .week {
      return "\(Int(7 * numberOfUnits))"
    }

    if trialPeriod.unit == .year {
      return "\(Int(365 * numberOfUnits))"
    }

    return "0"
  }

  var trialPeriodWeeks: String {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
      return "0"
    }
    let numberOfUnits = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return "\(Int(numberOfUnits / 7))"
    }

    if trialPeriod.unit == .month {
      return "\(4 * numberOfUnits)"
    }

    if trialPeriod.unit == .week {
      return "\(1 * numberOfUnits)"
    }

    if trialPeriod.unit == .year {
      return "\(52 * numberOfUnits)"
    }

    return "0"
  }

  var trialPeriodMonths: String {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
      return "0"
    }
    let numberOfUnits = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return "\(Int(numberOfUnits / 30))"
    }

    if trialPeriod.unit == .month {
      return "\(numberOfUnits * 1)"
    }

    if trialPeriod.unit == .week {
      return "\(Int(numberOfUnits / 4))"
    }

    if trialPeriod.unit == .year {
      return "\(numberOfUnits * 12)"
    }

    return "0"
  }

  var trialPeriodYears: String {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
      return "0"
    }
    let numberOfUnits = trialPeriod.numberOfUnits

    if trialPeriod.unit == .day {
      return "\(Int(numberOfUnits / 365))"
    }

    if trialPeriod.unit == .month {
      return "\(Int(numberOfUnits / 12))"
    }

    if trialPeriod.unit == .week {
      return "\(Int(numberOfUnits / 52))"
    }

    if trialPeriod.unit == .year {
      return "\(numberOfUnits)"
    }

    return "0"
  }

  var trialPeriodText: String {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
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
  // swiftlint:disable:next file_length
}
