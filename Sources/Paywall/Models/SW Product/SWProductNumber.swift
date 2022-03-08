//
//  SWProductNumber.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

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
