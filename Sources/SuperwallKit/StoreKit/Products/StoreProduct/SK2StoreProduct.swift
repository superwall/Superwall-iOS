//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  SK2StoreProduct.swift
//
//  Created by Nacho Soto on 12/20/21.
//  Updated by Yusuf Tör from Superwall on 11/8/22.
//  swiftlint:disable type_body_length file_length

import Foundation
import StoreKit

@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
struct SK2StoreProduct: StoreProductType {
  private let priceFormatterProvider = PriceFormatterProvider()
  let entitlements: Set<Entitlement>
  let billingPlanType: AppStoreProduct.BillingPlanType?

  /// Resolved at init from `pricingTerms` to avoid iterating the term list on
  /// every price/period accessor. `nil` when no billing plan is configured or
  /// when no matching term exists for the current runtime.
  private let cachedSelectedPrice: Decimal?
  private let cachedSelectedSubscriptionPeriod: StoreKit.Product.SubscriptionPeriod?
  private let cachedSelectedIntroductoryOffer: StoreKit.Product.SubscriptionOffer?
  private let cachedHasMatchedTerm: Bool

  init(
    sk2Product: SK2Product,
    entitlements: Set<Entitlement>,
    billingPlanType: AppStoreProduct.BillingPlanType? = nil
  ) {
    #if swift(<5.7)
    self._underlyingSK2Product = sk2Product
    #else
    self.underlyingSK2Product = sk2Product
    #endif
    self.entitlements = entitlements
    self.billingPlanType = billingPlanType

    #if compiler(>=6.3)
    if #available(iOS 26.4, macOS 26.4, tvOS 26.4, watchOS 26.4, visionOS 26.4, *),
      let term = Self.findPricingTerm(for: billingPlanType, in: sk2Product) {
      // Use the commitment *period* (= year for an annual MONTHLY product)
      // so the paywall reads as the underlying product (not its billing
      // cycle), then compute the total commitment price ourselves as
      // `billingPrice × cycles in commitment`. Apple's `commitmentInfo.price`
      // empirically returns the per-cycle amount, not the total — computing
      // from billingPrice + cycle count is robust either way and matches
      // the merchandising semantics the dashboard already enforces.
      // For UP_FRONT, billingPeriod == commitmentInfo.period so cycles = 1
      // and the result equals billingPrice — no change.
      let cycles = Self.cyclesInCommitment(
        billingUnit: term.billingPeriod.unit,
        billingValue: term.billingPeriod.value,
        commitmentUnit: term.commitmentInfo.period.unit,
        commitmentValue: term.commitmentInfo.period.value
      )
      self.cachedSelectedPrice = term.billingPrice * Decimal(cycles)
      self.cachedSelectedSubscriptionPeriod = term.commitmentInfo.period
      // Intro offers are per-billing-plan on iOS 26.4+: each `PricingTerms`
      // has its own `subscriptionOffers` array. Pull the plan-specific
      // introductory offer (if any) so the paywall surfaces the trial /
      // intro pricing configured against this billing plan rather than
      // the underlying SK2 product's default-plan offer.
      self.cachedSelectedIntroductoryOffer =
        term[offers: .introductory].first
      self.cachedHasMatchedTerm = true
    } else {
      self.cachedSelectedPrice = nil
      self.cachedSelectedSubscriptionPeriod = nil
      self.cachedSelectedIntroductoryOffer = nil
      self.cachedHasMatchedTerm = false
    }
    #else
    self.cachedSelectedPrice = nil
    self.cachedSelectedSubscriptionPeriod = nil
    self.cachedSelectedIntroductoryOffer = nil
    self.cachedHasMatchedTerm = false
    #endif
  }

  /// Counts how many billing cycles fit into one commitment period (e.g. 12
  /// for monthly billing on a yearly commitment).
  ///
  /// `.month`/`.year` are commensurable (1 year = 12 months) and `.day`/`.week`
  /// are commensurable (1 week = 7 days), so when both periods fall in the same
  /// family the count is computed by exact integer division — no calendar
  /// approximation. Only when the periods straddle the two families (e.g.
  /// weekly billing on a yearly commitment) do we fall back to a day
  /// approximation (month = 30 days, year = 365), which is inherently inexact
  /// but acceptable for those cross-unit pairings.
  ///
  /// Takes units/values rather than `StoreKit.Product.SubscriptionPeriod`
  /// because that type can't be constructed in unit tests.
  static func cyclesInCommitment(
    billingUnit: StoreKit.Product.SubscriptionPeriod.Unit,
    billingValue: Int,
    commitmentUnit: StoreKit.Product.SubscriptionPeriod.Unit,
    commitmentValue: Int
  ) -> Int {
    if let billing = monthsIn(unit: billingUnit, value: billingValue),
      let commitment = monthsIn(unit: commitmentUnit, value: commitmentValue) {
      return cycles(billing: billing, commitment: commitment)
    }
    if let billing = exactDaysIn(unit: billingUnit, value: billingValue),
      let commitment = exactDaysIn(unit: commitmentUnit, value: commitmentValue) {
      return cycles(billing: billing, commitment: commitment)
    }
    // Cross-family (e.g. week ↔ year): no exact conversion, approximate by days.
    return cycles(
      billing: daysIn(unit: billingUnit, value: billingValue),
      commitment: daysIn(unit: commitmentUnit, value: commitmentValue)
    )
  }

  /// Cycle count from two magnitudes expressed in the same unit. Rounds to
  /// nearest so the day-approximation fallback degrades gracefully; exact when
  /// the periods share a unit family.
  private static func cycles(billing: Int, commitment: Int) -> Int {
    guard billing > 0 else { return 1 }
    return max(Int((Double(commitment) / Double(billing)).rounded()), 1)
  }

  /// Months represented by a `.month`/`.year` period; `nil` for other units.
  private static func monthsIn(
    unit: StoreKit.Product.SubscriptionPeriod.Unit,
    value: Int
  ) -> Int? {
    switch unit {
    case .month: return value
    case .year: return value * 12
    default: return nil
    }
  }

  /// Exact days for a `.day`/`.week` period; `nil` for calendar-month units.
  private static func exactDaysIn(
    unit: StoreKit.Product.SubscriptionPeriod.Unit,
    value: Int
  ) -> Int? {
    switch unit {
    case .day: return value
    case .week: return value * 7
    default: return nil
    }
  }

  private static func daysIn(
    unit: StoreKit.Product.SubscriptionPeriod.Unit,
    value: Int
  ) -> Int {
    switch unit {
    case .day: return value
    case .week: return value * 7
    case .month: return value * 30
    case .year: return value * 365
    @unknown default: return value * 30
    }
  }

  func withBillingPlanType(
    _ billingPlanType: AppStoreProduct.BillingPlanType?
  ) -> any StoreProductType {
    return SK2StoreProduct(
      sk2Product: underlyingSK2Product,
      entitlements: entitlements,
      billingPlanType: billingPlanType
    )
  }

  #if swift(<5.7)
  // We can't directly store instances of StoreKit.Product, since that causes
  // linking issues in iOS < 15, even with @available checks correctly in place.
  // So instead, we store the underlying product as Any and wrap it with casting.
  private let _underlyingSK2Product: Any
  var underlyingSK2Product: SK2Product {
    // swiftlint:disable:next force_cast
    _underlyingSK2Product as! SK2Product
  }
  #else
  let underlyingSK2Product: SK2Product
  #endif

  var productIdentifier: String {
    underlyingSK2Product.id
  }

  var subscriptionGroupIdentifier: String? {
    underlyingSK2Product.subscription?.subscriptionGroupID
  }

  var swProduct: SWProduct {
    return SWProduct(product: underlyingSK2Product)
  }

  var localizedPrice: String {
    // A computed commitment total (billing price × cycles) isn't a native App
    // Store price point, so format it with the NumberFormatter — which doesn't
    // apply storefront price-point rounding — to preserve the exact sum the
    // user is charged. This matches the per-period computed accessors. The
    // native product price keeps Apple's price-point `priceFormatStyle`.
    if let computedPrice = cachedSelectedPrice {
      return priceFormatter.string(from: NSDecimalNumber(decimal: computedPrice)) ?? "n/a"
    }
    return underlyingSK2Product.price.formatted(underlyingSK2Product.priceFormatStyle)
  }

  /// The price to use for this product, routed through the selected billing
  /// plan's pricing term when one is configured and available, otherwise the
  /// underlying SK2 product's price.
  private var selectedPrice: Decimal {
    return cachedSelectedPrice ?? underlyingSK2Product.price
  }

  /// The subscription period to use for this product, routed through the
  /// selected billing plan's pricing term when one is configured and
  /// available, otherwise the underlying SK2 product's subscription period.
  private var selectedSubscriptionPeriod: StoreKit.Product.SubscriptionPeriod? {
    return cachedSelectedSubscriptionPeriod ?? underlyingSK2Product.subscription?.subscriptionPeriod
  }

  /// The introductory offer for this product, routed through the matched
  /// billing-plan pricing term's `subscriptionOffers` when a plan is
  /// configured (so the MONTHLY plan's intro offer is surfaced rather than
  /// the SK2 default plan's, and an *absent* intro offer on the chosen
  /// plan is honored even if a different plan has one). Falls back to the
  /// legacy `subscription?.introductoryOffer` only when no plan was
  /// matched — `cachedHasMatchedTerm` gates that explicitly so a nil
  /// cached offer doesn't silently re-surface the default plan's offer.
  private var selectedIntroductoryOffer: StoreKit.Product.SubscriptionOffer? {
    if cachedHasMatchedTerm {
      return cachedSelectedIntroductoryOffer
    }
    return underlyingSK2Product.subscription?.introductoryOffer
  }

  #if compiler(>=6.3)
  @available(iOS 26.4, macOS 26.4, tvOS 26.4, watchOS 26.4, visionOS 26.4, *)
  private static func findPricingTerm(
    for billingPlanType: AppStoreProduct.BillingPlanType?,
    in sk2Product: SK2Product
  ) -> StoreKit.Product.SubscriptionInfo.PricingTerms? {
    guard let plan = billingPlanType,
      let terms = sk2Product.subscription?.pricingTerms else {
      return nil
    }
    let target: StoreKit.Product.SubscriptionInfo.BillingPlanType
    switch plan {
    case .upFront: target = .upFront
    case .monthly: target = .monthly
    }
    return terms.first { $0.billingPlanType == target }
  }
  #endif

  var isBillingPlanAvailable: Bool {
    // "Is there a billing plan to use?" — `true` only when a plan is
    // configured AND the device exposes a matching pricing term. Legacy
    // products (no plan configured) return `false` so paywall templates
    // can gate billing-plan-specific copy on `isBillingPlanAvailable`
    // without separately checking `billingPlanType`.
    if billingPlanType == nil {
      return false
    }
    return cachedHasMatchedTerm
  }

  /// A `NumberFormatter` for formatting computed prices (daily, weekly, monthly, yearly).
  /// Unlike `priceFormatStyle`, this does not apply storefront-specific rounding
  /// that can cause values like £4.99 to display as £5.00 in production.
  private var priceFormatter: NumberFormatter {
    priceFormatterProvider.priceFormatterForSK2(
      withCurrencyCode: underlyingSK2Product.priceFormatStyle.currencyCode,
      locale: underlyingSK2Product.priceFormatStyle.locale
    )
  }

  var localizedSubscriptionPeriod: String {
    guard let subscriptionPeriod = selectedSubscriptionPeriod else {
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
    guard let subscriptionPeriod = selectedSubscriptionPeriod else {
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
    guard let subscriptionPeriod = selectedSubscriptionPeriod else {
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
    guard let subscriptionPeriod = selectedSubscriptionPeriod else {
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
    guard let subscriptionPeriod = selectedSubscriptionPeriod else {
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
    guard let subscriptionPeriod = selectedSubscriptionPeriod else {
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
    guard let subscriptionPeriod = selectedSubscriptionPeriod else {
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
    return formattedComputedPrice { $0.pricePerDay(withTotalPrice: $1) }
  }

  var weeklyPrice: String {
    return formattedComputedPrice { $0.pricePerWeek(withTotalPrice: $1) }
  }

  var monthlyPrice: String {
    return formattedComputedPrice { $0.pricePerMonth(withTotalPrice: $1) }
  }

  var yearlyPrice: String {
    return formattedComputedPrice { $0.pricePerYear(withTotalPrice: $1) }
  }

  /// Formats a per-period price derived from the *normalized* subscription
  /// period. `subscriptionPeriod` is built via `SubscriptionPeriod.from(...)`,
  /// which applies `normalized()` — collapsing StoreKit's occasional `.day × 7`
  /// into `.week × 1`. Without that, a weekly product reported by StoreKit in
  /// days would divide by an approximate day↔week factor and report a
  /// `weeklyPrice` a penny off (e.g. £6.99 → £7.00).
  private func formattedComputedPrice(
    _ perPeriod: (SubscriptionPeriod, Decimal) -> Decimal
  ) -> String {
    guard let subscriptionPeriod = subscriptionPeriod else {
      return "n/a"
    }
    let result = perPeriod(subscriptionPeriod, selectedPrice)
    return priceFormatter.string(from: NSDecimalNumber(decimal: result)) ?? "n/a"
  }

  var hasFreeTrial: Bool {
    return selectedIntroductoryOffer != nil
  }

  var trialPeriodEndDate: Date? {
    guard let trialPeriod = selectedIntroductoryOffer?.period else {
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

  private static let trialDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = .autoupdatingCurrent
    return formatter
  }()

  var trialPeriodEndDateString: String {
    trialPeriodEndDate.map { Self.trialDateFormatter.string(from: $0) } ?? ""
  }

  var trialPeriodDays: Int {
    guard let trialPeriod = selectedIntroductoryOffer?.period else {
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
    guard let trialPeriod = selectedIntroductoryOffer?.period else {
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
    guard let trialPeriod = selectedIntroductoryOffer?.period else {
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
    guard let trialPeriod = selectedIntroductoryOffer?.period else {
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
    guard let trialPeriod = selectedIntroductoryOffer?.period else {
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
    underlyingSK2Product.priceFormatStyle.locale.identifier
  }

  var languageCode: String? {
    underlyingSK2Product.priceFormatStyle.locale.languageCode
  }

  var currencyCode: String? {
    underlyingSK2Product.priceFormatStyle.locale.currencyCode
  }

  var currencySymbol: String? {
    underlyingSK2Product.priceFormatStyle.locale.currencySymbol
  }

  var regionCode: String? {
    underlyingSK2Product.priceFormatStyle.locale.regionCode
  }

  var price: Decimal {
    selectedPrice
  }

  var isFamilyShareable: Bool {
    underlyingSK2Product.isFamilyShareable
  }

  var subscriptionPeriod: SubscriptionPeriod? {
    guard let skSubscriptionPeriod = selectedSubscriptionPeriod else {
      return nil
    }
    return SubscriptionPeriod.from(sk2SubscriptionPeriod: skSubscriptionPeriod)
  }

  var introductoryDiscount: StoreProductDiscount? {
    selectedIntroductoryOffer
      .flatMap { StoreProductDiscount(sk2Discount: $0, currencyCode: currencyCode) }
  }

  var discounts: [StoreProductDiscount] {
    (underlyingSK2Product.subscription?.promotionalOffers ?? [])
      .compactMap { StoreProductDiscount(sk2Discount: $0, currencyCode: currencyCode) }
  }

  var trialPeriodPrice: Decimal {
    selectedIntroductoryOffer?.price ?? 0.00
  }

  func trialPeriodPricePerUnit(_ unit: SubscriptionPeriod.Unit) -> String {
    guard let introductoryDiscount = introductoryDiscount else {
      return priceFormatter.string(from: 0.00) ?? "n/a"
    }
    if introductoryDiscount.price == 0.00 {
      return priceFormatter.string(from: 0.00) ?? "n/a"
    }

    let introMonthlyPrice = introductoryDiscount.pricePerUnit(unit)

    return priceFormatter.string(from: NSDecimalNumber(decimal: introMonthlyPrice)) ?? "n/a"
  }

  var localizedTrialPeriodPrice: String {
    guard let price = selectedIntroductoryOffer?.price else {
      return Decimal(0).formatted(underlyingSK2Product.priceFormatStyle)
    }
    return price.formatted(underlyingSK2Product.priceFormatStyle)
  }
}

// MARK: - Hashable
@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension SK2StoreProduct: Hashable {
  static func == (lhs: SK2StoreProduct, rhs: SK2StoreProduct) -> Bool {
    return lhs.underlyingSK2Product == rhs.underlyingSK2Product
      && lhs.billingPlanType == rhs.billingPlanType
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.underlyingSK2Product)
    hasher.combine(self.billingPlanType)
  }
}
