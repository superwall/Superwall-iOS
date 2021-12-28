//
//  File.swift
//  
//
//  Created by Jake Mor on 12/26/21.
//

import Foundation
import StoreKit

//internal struct TemplateProduct: Codable {
//
//	var underlyingProduct: SWProduct
//
//	var legacy: [String: String]
//
//	var pricing: [String: String]
//
//	var period: [String: String]
//
//	var trial: [String: String]
//
//	init(skProduct: SKProduct) {
//		self.underlyingProduct = SWProduct(product: skProduct)
//		self.legacy = skProduct.legacyEventData
//	}
//
//}


// Product Abstraction

internal struct SWProduct: Codable {
	
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

		if #available(iOS 11.2, *) {
			if let p = product.subscriptionPeriod {
				subscriptionPeriod = SWProductSubscriptionPeriod(period: p)
			}
			if let d = product.introductoryPrice {
				introductoryPrice = SWProductDiscount(discount: d)
			}
		}

	}

}

internal struct SWProductDiscount: Codable {
	
	
	public enum PaymentMode: String, Codable {
		case payAsYouGo
		case payUpFront
		case freeTrial
		case unknown
	}

	public enum `Type`: String, Codable {
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
	
	@available(iOS 11.2, *)
	init(discount: SKProductDiscount) {
		price = discount.price.doubleValue
		priceLocale = discount.priceLocale.identifier
		if #available(iOS 12.2, *) {
			identifier = discount.identifier
		}
		subscriptionPeriod = SWProductSubscriptionPeriod(period: discount.subscriptionPeriod)
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
		
		if #available(iOS 12.2, *) {
			switch discount.type {
				case .introductory:
					self.type = .introductory
				case .subscription:
					self.type = .subscription
				@unknown default:
					self.type = .unknown
			}
		} else {
			self.type = .unknown
		}
		
		
	}
	
}


internal struct SWProductSubscriptionPeriod: Codable {
	
	public enum Unit: String, Codable {
		case day
		case week
		case month
		case year
		case unknown
	}
	
	public enum ColloquialUnit: String, Codable {
		case days
		case weeks
		case months
		case quarters
		case years
	}
	
	var numberOfUnits: Int
	
	var unit: SWProductSubscriptionPeriod.Unit
	
	@available(iOS 11.2, *)
	init(period: SKProductSubscriptionPeriod) {
		self.numberOfUnits = period.numberOfUnits
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
	
	func unitString(for cUnit: ColloquialUnit, pluralIfNeeded: Bool) -> String {
		
		let plural = (numberOfUnits(in: cUnit)) != 1 && pluralIfNeeded
		
		switch cUnit {
			case .days:
				return plural ? "days" : "day"
			case .weeks:
				return plural ? "weeks" : "week"
			case .months:
				return plural ? "months" : "month"
			case .quarters:
				return plural ? "quarters" : "quarter"
			case .years:
				return plural ? "years" : "year"
		}
	}
	
//	func string(for cUnit: ColloquialUnit, separator: String, plural: Bool) {
//		let n = round(numberOfUnits(in: cUnit) * 100) / 100 // make it 2 decimal places
//
//
//	}

}


internal struct ProductNumber {
	public enum Format: String, Codable {
		case number
		case currency
		case percent
	}
	
	var format: Format
	var value: Double
	var formatted: String?
	var pretty: String?

	var prettyValue: Double {
		return round(value / 0.05) * 0.05
	}
	
	init(value: Double, format: Format, locale: Locale) {
		self.value = value
		self.format = format
		
		switch format {
			case .number:
				let formatter = NumberFormatter()
				formatter.usesGroupingSeparator = true
				formatter.numberStyle = .decimal
				formatter.locale = locale
				formatter.maximumFractionDigits = 2
				formatter.minimumFractionDigits = 0
				self.formatted = formatter.string(from: NSNumber(value: self.value))
				self.pretty = formatter.string(from: NSNumber(value: self.prettyValue))
			case .currency:
				let formatter = NumberFormatter()
				formatter.usesGroupingSeparator = true
				formatter.numberStyle = .currency
				formatter.locale = locale
				self.formatted = formatter.string(from: NSNumber(value: self.value))
				self.pretty = formatter.string(from: NSNumber(value: self.prettyValue))
			case .percent:
				let formatter = NumberFormatter()
				formatter.usesGroupingSeparator = true
				formatter.numberStyle = .percent
				formatter.locale = locale
				formatter.minimumFractionDigits = 0
				self.formatted = formatter.string(from: NSNumber(value: self.value))
				self.pretty = formatter.string(from: NSNumber(value: self.prettyValue))
		}
		
		
	}
}


internal extension SKProduct {
	
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
			"identifier": productIdentifier,

		]
	}
	
	var eventData: JSON {
		var output = legacyEventData as [String: Any]
		output["new"] = swProduct.dictionary
		return JSON(output)
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
		guard #available(iOS 11.2, *), let subscriptionPeriod = self.subscriptionPeriod else { return "" }
		
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
		get {
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "" }

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
	}
	
	var periodWeeks: String {
		get {
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "" }
			let c = period.numberOfUnits
			
			if period.unit == .day {
				return "\(Int((1 * c)/7))"
			}
			
			if period.unit == .week {
				return "\(Int(c))"
			}
			
			if period.unit == .month {
				return "\(Int(4 * c))"
			}
			
			if period.unit == .year {
				return "\(Int(52 * c))"
			}

			return "0"
		}
	}
	
	var periodMonths: String {
		get {
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "" }
			let c = period.numberOfUnits
			
			if period.unit == .day {
				return "\(Int((1 * c)/30))"
			}
			
			if period.unit == .week {
				return "\(Int(c / 4))"
			}
			
			if period.unit == .month {
				return "\(Int(c))"
			}
			
			if period.unit == .year {
				return "\(Int(12 * c))"
			}

			return "0"
		}
	}
	
	var periodYears: String {
		get {
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "" }
			let c = period.numberOfUnits
			
			if period.unit == .day {
				return "\(Int(c / 365))"
			}
			
			if period.unit == .week {
				return "\(Int(c / 52))"
			}
			
			if period.unit == .month {
				return "\(Int(c / 12))"
			}
			
			if period.unit == .year {
				return "\(Int(c))"
			}

			return "0"
		}
	}
	
	var periodDays: String {
		get {
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "" }
			let c = period.numberOfUnits
			
			if period.unit == .day {
				return "\(Int(1 * c))"
			}
			
			if period.unit == .week {
				return "\(Int(7 * c))"
			}
			
			if period.unit == .month {
				return "\(Int(30 * c))"
			}
			
			if period.unit == .year {
				return "\(Int(365 * c))"
			}

			return "0"
		}
	}
	
	var dailyPrice: String {
		get {
			if price == NSDecimalNumber(decimal: 0.00) {
				return "$0.00"
			}
			
			let numberFormatter = NumberFormatter()
			let locale = priceLocale
			numberFormatter.numberStyle = .currency
			numberFormatter.locale = locale
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "n/a" }
			let c = period.numberOfUnits
			var periods = 1.0 as Decimal
			let inputPrice = price as Decimal
			
			if period.unit == .year {
				periods = Decimal(365 * c)
			}
			
			if period.unit == .month {
				periods = Decimal(30 * c)
			}
			
			if period.unit == .week {
				periods = Decimal(c) / Decimal(7)
			}
			
			if period.unit == .day {
				periods = Decimal(c) / Decimal(1)
			}
			
			return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
		}
	}

	var weeklyPrice: String {
		get {
			if price == NSDecimalNumber(decimal: 0.00) {
				return "$0.00"
			}
			
			let numberFormatter = NumberFormatter()
			let locale = priceLocale
			numberFormatter.numberStyle = .currency
			numberFormatter.locale = locale
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "n/a" }
			let c = period.numberOfUnits
			var periods = 1.0 as Decimal
			let inputPrice = price as Decimal
			
			if period.unit == .year {
				periods = Decimal(52 * c)
			}
			
			if period.unit == .month {
				periods = Decimal(4 * c)
			}
			
			if period.unit == .week {
				periods = Decimal(c) / Decimal(1)
			}
			
			if period.unit == .day {
				periods = Decimal(c) / Decimal(7)
			}
			
			return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
		}
	}
	
	var monthlyPrice: String {
		get {
			if price == NSDecimalNumber(decimal: 0.00) {
				return "$0.00"
			}
			
			let numberFormatter = NumberFormatter()
			let locale = priceLocale
			numberFormatter.numberStyle = .currency
			numberFormatter.locale = locale
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "n/a" }
			let c = period.numberOfUnits
			var periods = 1.0 as Decimal
			let inputPrice = price as Decimal
			
			if period.unit == .year {
				periods = Decimal(12 * c)
			}
			
			if period.unit == .month {
				periods = Decimal(1 * c)
			}
			
			if period.unit == .week {
				periods = Decimal(c) / Decimal(4)
			}
			
			if period.unit == .day {
				periods = Decimal(c) / Decimal(30)
			}
			
			return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
			
		}
	}
	
	var yearlyPrice: String {
		get {
			if price == NSDecimalNumber(decimal: 0.00) {
				return "$0.00"
			}
			
			let numberFormatter = NumberFormatter()
			let locale = priceLocale
			numberFormatter.numberStyle = .currency
			numberFormatter.locale = locale
			
			guard #available(iOS 11.2, *), let period = subscriptionPeriod else { return "n/a" }
			let c = period.numberOfUnits
			var periods = 1.0 as Decimal
			let inputPrice = price as Decimal
			
			if period.unit == .year {
				periods = Decimal(c)
			}
			
			if period.unit == .month {
				periods = Decimal(c) / Decimal(12)
			}
			
			if period.unit == .week {
				periods = Decimal(c) / Decimal(52)
			}
			
			if period.unit == .day {
				periods = Decimal(c) / Decimal(365)
			}
			
			return numberFormatter.string(from: NSDecimalNumber(decimal: inputPrice / periods)) ?? "N/A"
			
		}
	}

	var hasFreeTrial: Bool {
		get {
			if #available(iOS 11.2, *), let _ = introductoryPrice?.subscriptionPeriod {
				return true
			} else {
				return false
			}
		}
	}

	var trialPeriodDays: String {
		get {
			if #available(iOS 11.2, *), let trialPeriod = introductoryPrice?.subscriptionPeriod {
				let c = trialPeriod.numberOfUnits

				if trialPeriod.unit == .day {
					return "\(Int(1 * c))"
				}

				if trialPeriod.unit == .month {
					return "\(Int(30 * c))"
				}

				if trialPeriod.unit == .week {
					return "\(Int(7 * c))"
				}

				if trialPeriod.unit == .year {
					return "\(Int(365 * c))"
				}

			}

			return "0"
		}
	}
	
	var trialPeriodWeeks: String {
		get {
			if #available(iOS 11.2, *), let trialPeriod = introductoryPrice?.subscriptionPeriod {
				let c = trialPeriod.numberOfUnits

				if trialPeriod.unit == .day {
					return "\(Int(c / 7))"
				}

				if trialPeriod.unit == .month {
					return "\(4 * c)"
				}

				if trialPeriod.unit == .week {
					return "\(1 * c)"
				}

				if trialPeriod.unit == .year {
					return "\(52 * c)"
				}

			}

			return "0"
		}
	}
	
	var trialPeriodMonths: String {
		get {
			if #available(iOS 11.2, *), let trialPeriod = introductoryPrice?.subscriptionPeriod {
				let c = trialPeriod.numberOfUnits

				if trialPeriod.unit == .day {
					return "\(Int(c / 30))"
				}

				if trialPeriod.unit == .month {
					return "\(c * 1)"
				}

				if trialPeriod.unit == .week {
					return "\(Int(c / 4))"
				}

				if trialPeriod.unit == .year {
					return "\(c * 12)"
				}

			}

			return "0"
		}
	}
	
	var trialPeriodYears: String {
		get {
			if #available(iOS 11.2, *), let trialPeriod = introductoryPrice?.subscriptionPeriod {
				let c = trialPeriod.numberOfUnits

				if trialPeriod.unit == .day {
					return "\(Int(c / 365))"
				}

				if trialPeriod.unit == .month {
					return "\(Int(c / 12))"
				}

				if trialPeriod.unit == .week {
					return "\(Int(c / 52))"
				}

				if trialPeriod.unit == .year {
					return "\(c)"
				}

			}

			return "0"
		}
	}

	var trialPeriodText: String {
		get {

			if #available(iOS 11.2, *), let trialPeriod = introductoryPrice?.subscriptionPeriod {

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
			}

			return ""
		}
	}
}
