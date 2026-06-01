//
//  SK2PriceFormatRoundingTests.swift
//  SuperwallKitTests
//

import Foundation
import Testing
@testable import SuperwallKit

/// Regression tests for a bug where computed period prices (weekly/daily/monthly/yearly)
/// and `trialPeriodPricePerUnit` on `SK2StoreProduct` were rendered through
/// `StoreKit.Product.priceFormatStyle`, which applies storefront-specific rounding. A
/// £4.99/week product could therefore display as £5.00/week in production. The fix
/// switched these paths to use `PriceFormatterProvider.priceFormatterForSK2` — a plain
/// `NumberFormatter` that respects the currency's standard fraction digits without
/// storefront rounding. These tests guard the formatter chosen for computed values.
struct SK2PriceFormatRoundingTests {
  /// Demonstrates the production bug: a currency format style configured with an
  /// increment rounds 4.99 up to 5.00, whereas the NumberFormatter-based path used
  /// by `SK2StoreProduct` for computed period prices preserves 4.99.
  @Test("priceFormatterForSK2 preserves fractional values that a rounded currency style would distort")
  func testNumberFormatterPreservesValueThatPriceFormatStyleWouldRound() throws {
    // The Decimal.FormatStyle APIs below are iOS 15+. SuperwallKit ships with
    // an iOS 13 minimum so we guard at runtime rather than on the method signature
    // (the @Test macro is incompatible with @available attributes).
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else {
      return
    }
    let gbp = Locale(identifier: "en_GB")
    let value: Decimal = 4.99

    // Force 0 fraction digits — the shape of storefront-specific rounding that
    // caused £4.99/week to render as £5 in production.
    let storefrontRoundedStyle = Decimal.FormatStyle.Currency(code: "GBP")
      .locale(gbp)
      .precision(.fractionLength(0))
    let roundedOutput = value.formatted(storefrontRoundedStyle)
    #expect(
      roundedOutput == "£5",
      "Sanity check: a .precision(.fractionLength(0)) currency style must snap 4.99 to £5 (got \(roundedOutput))"
    )

    let formatter = PriceFormatterProvider().priceFormatterForSK2(
      withCurrencyCode: "GBP",
      locale: gbp
    )
    let fixedOutput = formatter.string(from: NSDecimalNumber(decimal: value))
    #expect(
      fixedOutput == "£4.99",
      "priceFormatterForSK2 must preserve 4.99 (got \(fixedOutput ?? "nil"))"
    )
    #expect(fixedOutput != roundedOutput)
  }

  /// Verifies the NumberFormatter path produces the expected 2-fraction-digit output
  /// across a few representative currency/locale pairs.
  @Test("priceFormatterForSK2 renders fractional prices using the currency's standard fraction digits")
  func testFormatsWithStandardFractionDigits() throws {
    let provider = PriceFormatterProvider()

    let gbp = provider.priceFormatterForSK2(
      withCurrencyCode: "GBP",
      locale: Locale(identifier: "en_GB")
    )
    #expect(gbp.string(from: NSDecimalNumber(decimal: 4.99)) == "£4.99")

    let usd = provider.priceFormatterForSK2(
      withCurrencyCode: "USD",
      locale: Locale(identifier: "en_US")
    )
    #expect(usd.string(from: NSDecimalNumber(decimal: 9.99)) == "$9.99")
  }
}
