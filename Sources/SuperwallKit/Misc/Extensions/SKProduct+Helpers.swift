//
//  SKProduct+Helpers.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import StoreKit

extension SKProduct {
  var attributes: [String: String] {
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
      "locale": priceLocale.identifier,
      "languageCode": priceLocale.languageCode ?? "n/a",
      "currencyCode": priceLocale.currencyCode ?? "n/a",
      "currencySymbol": priceLocale.currencySymbol ?? "n/a",
      "identifier": productIdentifier
    ]
  }

  var attributesJson: JSON {
    return JSON(attributes)
  }

  var swProductTemplateVariablesJson: JSON {
    return JSON(SWProductTemplateVariable(product: self).dictionary() as Any)
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
    guard let subscriptionPeriod = subscriptionPeriod else {
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

  var periodWeeks: Int {
    guard let subscriptionPeriod = subscriptionPeriod else {
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

  var periodWeeksString: String {
    return "\(periodWeeks)"
  }

  var periodMonths: Int {
    guard let subscriptionPeriod = subscriptionPeriod else {
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

  var periodMonthsString: String {
    return "\(periodMonths)"
  }

  var periodYears: Int {
    guard let subscriptionPeriod = subscriptionPeriod else {
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

  var periodYearsString: String {
    return "\(periodYears)"
  }

  var periodDays: Int {
    guard let subscriptionPeriod = subscriptionPeriod else {
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

  var periodDaysString: String {
    return "\(periodDays)"
  }

  var dailyPrice: String {
    if price == NSDecimalNumber(decimal: 0.00) {
      return "$0.00"
    }

    let numberFormatter = NumberFormatter()
    let locale = priceLocale
    numberFormatter.numberStyle = .currency
    numberFormatter.locale = locale

    guard let subscriptionPeriod = subscriptionPeriod else {
      return "n/a"
    }
    let numberOfUnits = subscriptionPeriod.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = price as Decimal

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

    guard let subscriptionPeriod = subscriptionPeriod else {
      return "n/a"
    }
    let numberOfUnits = subscriptionPeriod.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = price as Decimal

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

    guard let subscriptionPeriod = subscriptionPeriod else {
      return "n/a"
    }

    let numberOfUnits = subscriptionPeriod.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = price as Decimal

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

    guard let subscriptionPeriod = subscriptionPeriod else {
      return "n/a"
    }

    let numberOfUnits = subscriptionPeriod.numberOfUnits
    var periods = 1.0 as Decimal
    let inputPrice = price as Decimal

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

    return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
  }

  var hasFreeTrial: Bool {
    return introductoryPrice != nil
  }

  var trialPeriodEndDate: Date? {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
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
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
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

  var trialPeriodDaysString: String {
    return "\(trialPeriodDays)"
  }

  var trialPeriodWeeks: Int {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
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

  var trialPeriodWeeksString: String {
    return "\(trialPeriodWeeks)"
  }

  var trialPeriodMonths: Int {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
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

  var trialPeriodMonthsString: String {
    return "\(trialPeriodMonths)"
  }

  var trialPeriodYears: Int {
    guard let trialPeriod = introductoryPrice?.subscriptionPeriod else {
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

  var trialPeriodYearsString: String {
    return "\(trialPeriodYears)"
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
