//
//  File.swift
//  
//
//  Created by Jake Mor on 12/26/21.
//

import Foundation
import StoreKit

struct SWTemplateVariable: Codable {
	var raw: SWProduct?
	var subscription: SWSubscriptionTemplateVariable?
	var trial: SWSubscriptionTemplateVariable?
	var discount: SWSubscriptionTemplateVariable?
	var lifetime: SWSubscriptionTemplateVariable?
	var identifier: String

	var locale: String?
	var languageCode: String?
	var currencyCode: String?
	var currencySymbol: String?

	init(product: SKProduct) {
		self.locale = product.priceLocale.identifier
		self.languageCode = product.priceLocale.languageCode
		self.currencyCode = product.priceLocale.currencyCode
		self.currencySymbol = product.priceLocale.currencySymbol
		self.identifier = product.productIdentifier

		let subscription = SWSubscriptionTemplateVariable(type: .subscription, product: product)
		let trial = SWSubscriptionTemplateVariable(type: .trial, product: product)
    // let discount = SWSubscriptionTemplateVariable(type: .discount, product: product)
		let lifetime = SWSubscriptionTemplateVariable(type: .lifetime, product: product)

		self.subscription = subscription.exists ? subscription : nil
		self.trial = trial.exists ? trial : nil
    // self.discount = discount.exists ? discount : nil
		self.lifetime = lifetime.exists ? lifetime : nil
	}
}

struct SWSubscriptionTemplateVariable: Codable {
  enum TemplateType: String, Codable {
		case subscription
		case trial
		case discount
		case lifetime
	}

	var price: SWPriceTemplateVariable?
	var period: SWPeriodTemplateVariable?
	var identifier: String?
	var type: TemplateType
	var exists = true

	init(type: TemplateType, product: SKProduct) {
		let swProduct = SWProduct(product: product)
		self.type = type

    switch type {
    case .subscription:
      if let subscriptionPeriod = swProduct.subscriptionPeriod {
        self.identifier = swProduct.productIdentifier
        self.period = SWPeriodTemplateVariable(period: subscriptionPeriod, locale: product.priceLocale)
        self.price = SWPriceTemplateVariable(
          value: swProduct.price,
          locale: product.priceLocale,
          period: subscriptionPeriod
        )
        return
      }
    case .trial:
      if #available(iOS 11.2, *) {
        if let discount = swProduct.introductoryPrice {
          self.identifier = discount.identifier
          if discount.price != 0 {
            self.price = SWPriceTemplateVariable(
              value: discount.price,
              locale: product.priceLocale,
              period: discount.subscriptionPeriod
            )
          }
          self.period = SWPeriodTemplateVariable(period: discount.subscriptionPeriod, locale: product.priceLocale)
          return
        }
      }
    case .discount:
      break
    case .lifetime:
      if swProduct.subscriptionPeriod == nil {
        self.exists = true
        self.price = SWPriceTemplateVariable(value: swProduct.price, locale: product.priceLocale, period: nil)
      }
    }

		self.exists = false
	}
}

struct SWPriceTemplateVariable: Codable {
	var `default`: SWProductNumberGroup?
	var daily: SWProductNumberGroup?
	var weekly: SWProductNumberGroup?
	var monthly: SWProductNumberGroup?
	var quarterly: SWProductNumberGroup?
	var yearly: SWProductNumberGroup?

	var raw: SWProductNumber?
	var pretty: SWProductNumber?
	var rounded: SWProductNumber?

	init(value: Double, locale: Locale, period: SWProductSubscriptionPeriod?) {
		if let period = period {
			self.default = SWProductNumberGroup(
        value: period.price(for: value, in: period.colloquialUnit),
        format: .currency,
        locale: locale
      )
			self.daily = SWProductNumberGroup(value: period.price(for: value, in: .days), format: .currency, locale: locale)
			self.weekly = SWProductNumberGroup(value: period.price(for: value, in: .weeks), format: .currency, locale: locale)
			self.monthly = SWProductNumberGroup(value: period.price(for: value, in: .months), format: .currency, locale: locale)
			self.quarterly = SWProductNumberGroup(
        value: period.price(for: value, in: .quarters),
        format: .currency,
        locale: locale
      )
			self.yearly = SWProductNumberGroup(value: period.price(for: value, in: .years), format: .currency, locale: locale)
		} else {
			let numberGroup = SWProductNumberGroup(value: value, format: .currency, locale: locale)
			self.raw = numberGroup.raw
			self.pretty = numberGroup.pretty
			self.rounded = numberGroup.rounded
		}
	}
}

struct SWProductPeriod: Codable {
	var full: String?
	var short: String?
	var abbreviated: String?
	var duration: SWProductNumberGroup?

	init(units: SWProductSubscriptionPeriod.ColloquialUnit, period: SWProductSubscriptionPeriod, locale: Locale) {
		self.full = period.period(in: units, unitsStyle: .full)
		self.short = period.period(in: units, unitsStyle: .short)
		self.abbreviated = period.period(in: units, unitsStyle: .abbreviated)
		self.duration = SWProductNumberGroup(value: period.numberOfUnits(in: units), format: .number, locale: locale)
	}
}

struct SWPeriodTemplateVariable: Codable {
	var `default`: SWProductPeriod
	var daily: SWProductPeriod
	var weekly: SWProductPeriod
	var monthly: SWProductPeriod
	var quarterly: SWProductPeriod
	var yearly: SWProductPeriod

	init(period: SWProductSubscriptionPeriod, locale: Locale) {
		self.default = SWProductPeriod(units: period.colloquialUnit, period: period, locale: locale)
		self.daily = SWProductPeriod(units: .days, period: period, locale: locale)
		self.weekly = SWProductPeriod(units: .weeks, period: period, locale: locale)
		self.monthly = SWProductPeriod(units: .months, period: period, locale: locale)
		self.quarterly = SWProductPeriod(units: .quarters, period: period, locale: locale)
		self.yearly = SWProductPeriod(units: .years, period: period, locale: locale)
	}
}


// Product Abstraction

struct SWProduct: Codable {
	var localizedDescription: String
	var localizedTitle: String
	var price: Double
	var priceLocale: String
	var productIdentifier: String
	var isDownloadable: Bool
	var downloadContentLengths: [Double]
	var contentVersion: String
	var downloadContentVersion: String
	var isFamilyShareable: Bool?
	var subscriptionGroupIdentifier: String?
	var discounts: [SWProductDiscount]?
	var subscriptionPeriod: SWProductSubscriptionPeriod?
	var introductoryPrice: SWProductDiscount?

	init(product: SKProduct) {
		localizedDescription = product.localizedDescription
		localizedTitle = product.localizedTitle
		price = product.price.doubleValue
		priceLocale = product.priceLocale.identifier
		productIdentifier = product.productIdentifier
		isDownloadable = product.isDownloadable
		downloadContentLengths = product.downloadContentLengths.map { $0.doubleValue }
		contentVersion = product.contentVersion
		downloadContentVersion = product.downloadContentVersion

		if #available(iOS 14.0, *) {
			isFamilyShareable = product.isFamilyShareable
		}

		if #available(iOS 12.2, *) {
			discounts = product.discounts.map(SWProductDiscount.init)
		}

		if #available(iOS 12.0, *) {
			subscriptionGroupIdentifier = product.subscriptionGroupIdentifier
		}

		if #available(iOS 12.2, *) {
			if let period = product.subscriptionPeriod {
				subscriptionPeriod = SWProductSubscriptionPeriod(period: period, numberOfPeriods: 1)
			}
			if let discount = product.introductoryPrice {
				introductoryPrice = SWProductDiscount(discount: discount)
			}
		}
	}
}

struct SWProductDiscount: Codable {
	enum PaymentMode: String, Codable {
		case payAsYouGo
		case payUpFront
		case freeTrial
		case unknown
	}

  enum `Type`: String, Codable {
		case introductory
		case subscription
		case unknown
	}

	var price: Double
	var priceLocale: String
	var identifier: String?
	var subscriptionPeriod: SWProductSubscriptionPeriod
	var numberOfPeriods: Int
	var paymentMode: SWProductDiscount.PaymentMode
	var type: SWProductDiscount.`Type`

	@available(iOS 12.2, *)
	init(discount: SKProductDiscount) {
		price = discount.price.doubleValue
		priceLocale = discount.priceLocale.identifier
		identifier = discount.identifier
		subscriptionPeriod = SWProductSubscriptionPeriod(
      period: discount.subscriptionPeriod,
      numberOfPeriods: discount.numberOfPeriods
    )
		numberOfPeriods = discount.numberOfPeriods

    switch discount.paymentMode {
    case .freeTrial:
      self.paymentMode = .freeTrial
    case .payAsYouGo:
      self.paymentMode = .payAsYouGo
    case .payUpFront:
      self.paymentMode = .payUpFront
    @unknown default:
      self.paymentMode = .unknown
    }

    switch discount.type {
    case .introductory:
      self.type = .introductory
    case .subscription:
      self.type = .subscription
    @unknown default:
      self.type = .unknown
    }
	}
}

struct SWProductSubscriptionPeriod: Codable {
	enum Unit: String, Codable {
		case day
		case week
		case month
		case year
		case unknown
	}

  enum ColloquialUnit: String, Codable {
		case days
		case weeks
		case months
		case quarters
		case years
	}

	var numberOfUnits: Int

	var unit: SWProductSubscriptionPeriod.Unit

	var colloquialUnit: ColloquialUnit {
		if numberOfUnits(in: .days) == 1 {
			return .days
		}

		if numberOfUnits(in: .weeks) == 1 {
			return .weeks
		}

		if numberOfUnits(in: .months) == 1 {
			return .months
		}

		if numberOfUnits(in: .quarters) == 1 {
			return .quarters
		}

		if numberOfUnits(in: .years) == 1 {
			return .years
		}

    switch unit {
    case .day:
      return .days
    case .week:
      return .weeks
    case .month:
      return .months
    case .year:
      return .years
    case .unknown:
      return .months
    }
	}

	@available(iOS 11.2, *)
	init(period: SKProductSubscriptionPeriod, numberOfPeriods: Int) {
		self.numberOfUnits = period.numberOfUnits * numberOfPeriods
    switch period.unit {
    case .day:
      self.unit = .day
    case .week:
      self.unit = .week
    case .month:
      self.unit = .month
    case .year:
      self.unit = .year
    @unknown default:
      self.unit = .unknown
    }
	}

	var numberOfUnitsDouble: Double {
		return Double(numberOfUnits)
	}

	var daysPerUnit: Double {
    switch unit {
    case .day:
      return 1
    case .week:
      return 7
    case .month:
      return 30
    case .year:
      return 365
    case .unknown:
      return 1
    }
	}

	var weeksPerUnit: Double {
    switch unit {
    case .day:
      return 1.0 / 7
    case .week:
      return 1
    case .month:
      return 4
    case .year:
      return 52
    case .unknown:
      return 1
    }
	}

	var monthsPerUnit: Double {
    switch unit {
    case .day:
      return 1.0 / 30
    case .week:
      return 1.0 / 4
    case .month:
      return 1
    case .year:
      return 12
    case .unknown:
      return 1
    }
	}

	var quartersPerUnit: Double {
    switch unit {
    case .day:
      return 1.0 / 91.25
    case .week:
      return 1.0 / 13.0
    case .month:
      return 1.0 / 3.0
    case .year:
      return 4
    case .unknown:
      return 1
    }
	}

	var yearsPerUnit: Double {
    switch unit {
    case .day:
      return 1.0 / 365
    case .week:
      return 1.0 / 52.0
    case .month:
      return 1.0 / 12.0
    case .year:
      return 1
    case .unknown:
      return 1
    }
	}

	func numberOfUnits(in cUnit: ColloquialUnit) -> Double {
    switch cUnit {
    case .days:
      return daysPerUnit * numberOfUnitsDouble
    case .weeks:
      return weeksPerUnit * numberOfUnitsDouble
    case .months:
      return monthsPerUnit * numberOfUnitsDouble
    case .quarters:
      return quartersPerUnit * numberOfUnitsDouble
    case .years:
      return yearsPerUnit * numberOfUnitsDouble
    }
	}

	func numberOfUnits(in cUnit: ColloquialUnit) -> Int {
    switch cUnit {
    case .days:
      return Int(round(daysPerUnit * numberOfUnitsDouble))
    case .weeks:
      return Int(round(weeksPerUnit * numberOfUnitsDouble))
    case .months:
      return Int(round(monthsPerUnit * numberOfUnitsDouble))
    case .quarters:
      return Int(round(quartersPerUnit * numberOfUnitsDouble))
    case .years:
      return Int(round(yearsPerUnit * numberOfUnitsDouble))
    }
	}

	func price(for value: Double, in cUnit: ColloquialUnit) -> Double {
		let units: Double = numberOfUnits(in: cUnit)
		return value / units
	}

	func string(for cUnit: ColloquialUnit, unitsStyle: DateComponentsFormatter.UnitsStyle) -> String? {
		let formatter = DateComponentsFormatter()
		formatter.allowsFractionalUnits = true
		formatter.unitsStyle = unitsStyle
		let numberOfUnits: Int = numberOfUnits(in: .days)

    switch cUnit {
    case .days:
      formatter.allowedUnits = [.day]
      return formatter.string(from: DateComponents(day: numberOfUnits))
    case .weeks:
      formatter.allowedUnits = [.weekOfMonth]
      return formatter.string(from: DateComponents(day: numberOfUnits))
    case .months:
      formatter.allowedUnits = [.month]
      return formatter.string(from: DateComponents(day: numberOfUnits))
    case .quarters:
      let numberFormatter = NumberFormatter()
      numberFormatter.maximumFractionDigits = 2
      numberFormatter.minimumFractionDigits = 0

      let numberOfQuarters: Double = self.numberOfUnits(in: .quarters)
      if let quarters = numberFormatter.string(from: NSNumber(value: numberOfQuarters)) {
        return numberOfQuarters == 1.0 ? "\(numberOfUnits) quarter" : "\(quarters) quarters"
      } else {
        return numberOfQuarters == 1.0 ? "\(numberOfUnits) quarter" : "\(numberOfUnits) quarters"
      }
    case .years:
      formatter.allowedUnits = [.year]
      return formatter.string(from: DateComponents(day: numberOfUnits))
    }
	}

	func unit(from: String) -> String {
		let forbidden = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
		return from.removeCharacters(from: forbidden).trimmingCharacters(in: .whitespacesAndNewlines)
	}

	func period(in cUnit: ColloquialUnit, unitsStyle: DateComponentsFormatter.UnitsStyle) -> String? {
		if numberOfUnits(in: cUnit) == 1 {
			return unitString(for: cUnit, unitsStyle: unitsStyle)
		} else {
			return string(for: cUnit, unitsStyle: unitsStyle)
		}
	}

	func unitString(for cUnit: ColloquialUnit, unitsStyle: DateComponentsFormatter.UnitsStyle) -> String? {
		if let string = string(for: cUnit, unitsStyle: unitsStyle) {
			return unit(from: string)
		}

		return nil
	}
}

struct SWProductNumber: Codable {
	enum Format: String, Codable {
		case number
		case currency
		case percent
	}

	var format: Format
	var formatted: String?
	var value: Decimal

	init(value: Double, format: Format, locale: Locale) {
		let formatter = NumberFormatter()
		formatter.usesGroupingSeparator = true
		formatter.numberStyle = .decimal
		formatter.locale = locale
		formatter.maximumFractionDigits = 2
		formatter.minimumFractionDigits = 0

		if let formattedString = formatter.string(from: NSNumber(value: value)) {
			self.value = Decimal(string: formattedString) ?? Decimal(value)
		} else {
			self.value = Decimal(value)
		}

		self.format = format

    switch format {
    case .number:
      let formatter = NumberFormatter()
      formatter.usesGroupingSeparator = true
      formatter.numberStyle = .decimal
      formatter.locale = locale
      formatter.maximumFractionDigits = 2
      formatter.minimumFractionDigits = 0
      self.formatted = formatter.string(from: NSNumber(value: value))
    case .currency:
      let formatter = NumberFormatter()
      formatter.usesGroupingSeparator = true
      formatter.numberStyle = .currency
      formatter.locale = locale
      self.formatted = formatter.string(from: NSNumber(value: value))
    case .percent:
      let formatter = NumberFormatter()
      formatter.usesGroupingSeparator = true
      formatter.numberStyle = .percent
      formatter.locale = locale
      formatter.minimumFractionDigits = 0
      self.formatted = formatter.string(from: NSNumber(value: value))
    }
	}
}

struct SWProductNumberGroup: Codable {
	var raw: SWProductNumber?
	var pretty: SWProductNumber?
	var rounded: SWProductNumber?

	init(value: Double, format: SWProductNumber.Format, locale: Locale) {
		let rawValue = value
		let roundedValue = round(value * 100) / 100
		var prettyValue = round(value / 0.05) * 0.05

		if format == .currency {
			prettyValue = round(rawValue / 0.1) * 0.1 - 0.01
		}

		self.raw = SWProductNumber(value: rawValue, format: format, locale: locale)
		self.rounded = SWProductNumber(value: roundedValue, format: format, locale: locale)
		self.pretty = SWProductNumber(value: prettyValue, format: format, locale: locale)
	}
}

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
		guard
      #available(iOS 11.2, *),
      let subscriptionPeriod = self.subscriptionPeriod
    else {
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
    guard
      #available(iOS 11.2, *),
      let period = subscriptionPeriod
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
    guard
      #available(iOS 11.2, *),
      let period = subscriptionPeriod
    else {
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
    guard
      #available(iOS 11.2, *),
      let period = subscriptionPeriod
    else {
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
    guard
      #available(iOS 11.2, *),
        let period = subscriptionPeriod
    else {
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
    guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "" }
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

    guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "n/a" }
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

    guard
      #available(iOS 11.2, *),
      let period = subscriptionPeriod
    else {
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

    guard
      #available(iOS 11.2, *),
        let period = subscriptionPeriod
    else {
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

    guard
      #available(iOS 11.2, *),
      let period = subscriptionPeriod
    else {
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
    if #available(iOS 11.2, *),
      introductoryPrice?.subscriptionPeriod != nil {
      return true
    } else {
      return false
    }
	}

	var trialPeriodDays: String {
    guard
      #available(iOS 11.2, *),
      let trialPeriod = introductoryPrice?.subscriptionPeriod
    else {
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
    guard
      #available(iOS 11.2, *),
      let trialPeriod = introductoryPrice?.subscriptionPeriod
    else {
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
    guard
      #available(iOS 11.2, *),
      let trialPeriod = introductoryPrice?.subscriptionPeriod
    else {
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
    guard
      #available(iOS 11.2, *),
      let trialPeriod = introductoryPrice?.subscriptionPeriod
    else {
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
    guard
      #available(iOS 11.2, *),
      let trialPeriod = introductoryPrice?.subscriptionPeriod
    else {
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
