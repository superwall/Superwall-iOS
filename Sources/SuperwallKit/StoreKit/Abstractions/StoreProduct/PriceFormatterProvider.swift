//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  PriceFormatterProvider.swift
//
//  Created by Juanpe Catalán on 10/3/22.
//  Updated by Yusuf Tör from Superwall on 11/8/22.

import Foundation

/// A `NumberFormatter` provider class for prices.
/// This provider caches the formatter to improve the performance.
final class PriceFormatterProvider {
  private var cachedPriceFormatterForSK1: NumberFormatter?
  private var cachedPriceFormatterForSK2: NumberFormatter?

  func priceFormatterForSK1(with locale: Locale) -> NumberFormatter {
    func makePriceFormatterForSK1(with locale: Locale) -> NumberFormatter {
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.locale = locale
      return formatter
    }

    guard
      let formatter = cachedPriceFormatterForSK1,
      formatter.locale == locale
    else {
      let newFormatter = makePriceFormatterForSK1(with: locale)
      cachedPriceFormatterForSK1 = newFormatter
      return newFormatter
    }
    return formatter
  }

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  func priceFormatterForSK2(withCurrencyCode currencyCode: String) -> NumberFormatter {
    func makePriceFormatterForSK2(with currencyCode: String) -> NumberFormatter {
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.locale = .autoupdatingCurrent
      formatter.currencyCode = currencyCode
      return formatter
    }

    guard
      let formatter = cachedPriceFormatterForSK2,
      formatter.currencyCode == currencyCode
    else {
      let newFormatter = makePriceFormatterForSK2(with: currencyCode)
      cachedPriceFormatterForSK2 = newFormatter

      return newFormatter
    }

    return formatter
  }
}
