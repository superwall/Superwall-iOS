//
//  APIStoreProduct.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-01-27.
//
// swiftlint:disable type_body_length

import Foundation
import StoreKit

/// A `StoreProductType` backed by a `SuperwallProduct` from the Superwall API.
///
/// Used for API-backed products that are not fetched from StoreKit — covers both
/// test store products in test mode and custom products purchased via an external
/// `PurchaseController`.
struct APIStoreProduct: StoreProductType {
  let superwallProduct: SuperwallProduct
  let entitlements: Set<Entitlement>

  private let priceFormatterProvider = PriceFormatterProvider()

  private var subscriptionUnit: SubscriptionPeriod.Unit? {
    guard let sub = superwallProduct.subscription else { return nil }
    switch sub.period {
    case .day: return .day
    case .week: return .week
    case .month: return .month
    case .year: return .year
    }
  }

  private var subscriptionValue: Int {
    superwallProduct.subscription?.periodCount ?? 0
  }

  var productIdentifier: String {
    superwallProduct.identifier
  }

  var price: Decimal {
    guard let amount = superwallProduct.price?.amount else { return 0 }
    // amount is in cents
    return Decimal(amount) / 100
  }

  var localizedPrice: String {
    return priceFormatter.string(from: NSDecimalNumber(decimal: price)) ?? "$\(price)"
  }

  var currencyCode: String? {
    superwallProduct.price?.currency.uppercased()
  }

  var currencySymbol: String? {
    priceFormatter.currencySymbol
  }

  let subscriptionGroupIdentifier: String? = nil

  var swProduct: SWProduct {
    SWProduct(product: self)
  }

  var localizedSubscriptionPeriod: String {
    guard let unit = subscriptionUnit else { return "" }
    let dateComponents: DateComponents
    switch unit {
    case .day: dateComponents = DateComponents(day: subscriptionValue)
    case .week: dateComponents = DateComponents(weekOfMonth: subscriptionValue)
    case .month: dateComponents = DateComponents(month: subscriptionValue)
    case .year: dateComponents = DateComponents(year: subscriptionValue)
    @unknown default: dateComponents = DateComponents(month: subscriptionValue)
    }
    return DateComponentsFormatter.localizedString(from: dateComponents, unitsStyle: .short) ?? ""
  }

  var period: String {
    guard let unit = subscriptionUnit else { return "" }
    switch unit {
    case .day:
      return subscriptionValue == 7 ? "week" : "day"
    case .week:
      return "week"
    case .month:
      switch subscriptionValue {
      case 2: return "2 months"
      case 3: return "quarter"
      case 6: return "6 months"
      default: return "month"
      }
    case .year:
      return "year"
    @unknown default:
      return ""
    }
  }

  var periodly: String {
    guard let unit = subscriptionUnit else { return "" }
    if unit == .month {
      switch subscriptionValue {
      case 2, 6:
        return "every \(period)"
      default:
        break
      }
    }
    return "\(period)ly"
  }

  var periodWeeks: Int {
    guard let unit = subscriptionUnit else { return 0 }
    switch unit {
    case .day: return subscriptionValue / 7
    case .week: return subscriptionValue
    case .month: return 4 * subscriptionValue
    case .year: return 52 * subscriptionValue
    @unknown default: return 0
    }
  }

  var periodWeeksString: String { "\(periodWeeks)" }

  var periodMonths: Int {
    guard let unit = subscriptionUnit else { return 0 }
    switch unit {
    case .day: return subscriptionValue / 30
    case .week: return subscriptionValue / 4
    case .month: return subscriptionValue
    case .year: return 12 * subscriptionValue
    @unknown default: return 0
    }
  }

  var periodMonthsString: String { "\(periodMonths)" }

  var periodYears: Int {
    guard let unit = subscriptionUnit else { return 0 }
    switch unit {
    case .day: return subscriptionValue / 365
    case .week: return subscriptionValue / 52
    case .month: return subscriptionValue / 12
    case .year: return subscriptionValue
    @unknown default: return 0
    }
  }

  var periodYearsString: String { "\(periodYears)" }

  var periodDays: Int {
    guard let unit = subscriptionUnit else { return 0 }
    switch unit {
    case .day: return subscriptionValue
    case .week: return 7 * subscriptionValue
    case .month: return 30 * subscriptionValue
    case .year: return 365 * subscriptionValue
    @unknown default: return 0
    }
  }

  var periodDaysString: String { "\(periodDays)" }

  // MARK: - Computed Prices

  /// A locale derived from the product's `storefront` country code so
  /// currency rendering matches what Apple returns for App Store products
  /// (e.g. USD on any device → `$3.99`, not `US$3.99`). Unrecognized
  /// storefronts fall back to `en_US` since Superwall products are USD-only
  /// today.
  private var storefrontLocale: Locale {
    if #available(iOS 16.0, *) {
      let region = Locale.Region(superwallProduct.storefront)
      if Locale.Region.isoRegions.contains(region) {
        var components = Locale.Components(languageCode: .english)
        components.region = region
        return Locale(components: components)
      }
    }
    return Locale(identifier: "en_US")
  }

  private var priceFormatter: NumberFormatter {
    return priceFormatterProvider.priceFormatterForSK2(
      withCurrencyCode: currencyCode ?? "USD",
      locale: storefrontLocale
    )
  }

  var dailyPrice: String {
    guard price != 0, let unit = subscriptionUnit else {
      return priceFormatter.string(from: 0) ?? "$0.00"
    }
    let days: Decimal
    switch unit {
    case .day: days = Decimal(subscriptionValue)
    case .week: days = Decimal(7) * Decimal(subscriptionValue)
    case .month: days = Decimal(365) / Decimal(12) * Decimal(subscriptionValue)
    case .year: days = Decimal(365 * subscriptionValue)
    @unknown default: days = 1
    }
    let rounded = (price / days).roundedPrice()
    return priceFormatter.string(from: NSDecimalNumber(decimal: rounded)) ?? "n/a"
  }

  var weeklyPrice: String {
    guard price != 0, let unit = subscriptionUnit else {
      return priceFormatter.string(from: 0) ?? "$0.00"
    }
    let weeks: Decimal
    switch unit {
    case .day: weeks = Decimal(subscriptionValue) / Decimal(7)
    case .week: weeks = Decimal(subscriptionValue)
    case .month: weeks = Decimal(52) / Decimal(12) * Decimal(subscriptionValue)
    case .year: weeks = Decimal(52 * subscriptionValue)
    @unknown default: weeks = 1
    }
    let rounded = (price / weeks).roundedPrice()
    return priceFormatter.string(from: NSDecimalNumber(decimal: rounded)) ?? "n/a"
  }

  var monthlyPrice: String {
    guard price != 0, let unit = subscriptionUnit else {
      return priceFormatter.string(from: 0) ?? "$0.00"
    }
    let months: Decimal
    switch unit {
    case .day: months = Decimal(subscriptionValue) * Decimal(12) / Decimal(365)
    case .week: months = Decimal(subscriptionValue) * Decimal(12) / Decimal(52)
    case .month: months = Decimal(subscriptionValue)
    case .year: months = Decimal(12 * subscriptionValue)
    @unknown default: months = 1
    }
    let rounded = (price / months).roundedPrice()
    return priceFormatter.string(from: NSDecimalNumber(decimal: rounded)) ?? "n/a"
  }

  var yearlyPrice: String {
    guard price != 0, let unit = subscriptionUnit else {
      return priceFormatter.string(from: 0) ?? "$0.00"
    }
    let years: Decimal
    switch unit {
    case .day: years = Decimal(subscriptionValue) / 365
    case .week: years = Decimal(subscriptionValue) / 52
    case .month: years = Decimal(subscriptionValue) / 12
    case .year: years = Decimal(subscriptionValue)
    @unknown default: years = 1
    }
    let rounded = (price / years).roundedPrice()
    return priceFormatter.string(from: NSDecimalNumber(decimal: rounded)) ?? "n/a"
  }

  // MARK: - Trial

  var hasFreeTrial: Bool {
    guard let trialDays = superwallProduct.subscription?.trialPeriodDays else { return false }
    return trialDays > 0
  }

  var trialPeriodEndDate: Date? {
    guard let trialDays = superwallProduct.subscription?.trialPeriodDays, trialDays > 0 else {
      return nil
    }
    return Calendar.current.date(byAdding: .day, value: trialDays, to: Date())
  }

  var trialPeriodEndDateString: String {
    guard let date = trialPeriodEndDate else { return "" }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = .autoupdatingCurrent
    return formatter.string(from: date)
  }

  private var rawTrialPeriodPrice: Decimal {
    guard let amount = superwallProduct.subscription?.trialPeriodPrice?.amount else { return 0 }
    return Decimal(amount) / 100
  }

  var localizedTrialPeriodPrice: String {
    priceFormatter.string(from: NSDecimalNumber(decimal: rawTrialPeriodPrice)) ?? "$0.00"
  }

  var trialPeriodPrice: Decimal { rawTrialPeriodPrice }

  func trialPeriodPricePerUnit(_ unit: SubscriptionPeriod.Unit) -> String {
    guard
      rawTrialPeriodPrice != 0,
      subscriptionUnit != nil
    else {
      return priceFormatter.string(from: NSDecimalNumber(decimal: rawTrialPeriodPrice)) ?? "$0.00"
    }
    let trialDays = Decimal(superwallProduct.subscription?.trialPeriodDays ?? 0)
    guard trialDays > 0 else {
      return priceFormatter.string(from: NSDecimalNumber(decimal: rawTrialPeriodPrice)) ?? "$0.00"
    }
    let dailyPrice = rawTrialPeriodPrice / trialDays
    let multiplier: Decimal
    switch unit {
    case .day: multiplier = 1
    case .week: multiplier = 7
    case .month: multiplier = Decimal(365) / Decimal(12)
    case .year: multiplier = 365
    @unknown default: multiplier = 1
    }
    let unitPrice = (dailyPrice * multiplier).roundedPrice()
    return priceFormatter.string(from: NSDecimalNumber(decimal: unitPrice)) ?? "n/a"
  }

  var trialPeriodDays: Int {
    superwallProduct.subscription?.trialPeriodDays ?? 0
  }

  var trialPeriodDaysString: String { "\(trialPeriodDays)" }

  var trialPeriodWeeks: Int {
    trialPeriodDays / 7
  }

  var trialPeriodWeeksString: String { "\(trialPeriodWeeks)" }

  var trialPeriodMonths: Int {
    trialPeriodDays / 30
  }

  var trialPeriodMonthsString: String { "\(trialPeriodMonths)" }

  var trialPeriodYears: Int {
    trialPeriodDays / 365
  }

  var trialPeriodYearsString: String { "\(trialPeriodYears)" }

  var trialPeriodText: String {
    guard trialPeriodDays > 0 else { return "" }
    return "\(trialPeriodDays)-day"
  }

  // MARK: - Locale

  var locale: String {
    Locale.current.identifier
  }

  var languageCode: String? {
    Locale.current.languageCode
  }

  var regionCode: String? {
    Locale.current.regionCode
  }

  let isFamilyShareable = false

  var subscriptionPeriod: SubscriptionPeriod? {
    guard let unit = subscriptionUnit else { return nil }
    return SubscriptionPeriod(value: subscriptionValue, unit: unit)
  }

  var introductoryDiscount: StoreProductDiscount? { nil }

  let discounts: [StoreProductDiscount] = []
}

// MARK: - SWProduct Init
extension SWProduct {
  init(product: APIStoreProduct) {
    localizedDescription = ""
    localizedTitle = product.superwallProduct.identifier
    price = product.price
    priceLocale = product.locale
    productIdentifier = product.productIdentifier
    isDownloadable = false
    downloadContentLengths = []
    contentVersion = ""
    downloadContentVersion = ""
    isFamilyShareable = product.isFamilyShareable
    subscriptionGroupIdentifier = product.subscriptionGroupIdentifier

    if let period = product.subscriptionPeriod {
      self.subscriptionPeriod = SWProductSubscriptionPeriod(
        period: period,
        numberOfPeriods: 1
      )
    }
  }
}
