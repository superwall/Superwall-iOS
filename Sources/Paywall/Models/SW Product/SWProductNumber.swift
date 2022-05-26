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

  init(value: Decimal, format: Format, locale: Locale) {
    self.value = value.rounded(2, .down)
    self.format = format

    switch format {
    case .number:
      let formatter = NumberFormatter()
      formatter.usesGroupingSeparator = true
      formatter.numberStyle = .decimal
      formatter.locale = locale
      formatter.maximumFractionDigits = 2
      formatter.minimumFractionDigits = 0
      self.formatted = formatter.string(from: value as NSDecimalNumber)
    case .currency:
      let formatter = NumberFormatter()
      formatter.usesGroupingSeparator = true
      formatter.numberStyle = .currency
      formatter.locale = locale
      self.formatted = formatter.string(from: value as NSDecimalNumber)
    case .percent:
      let formatter = NumberFormatter()
      formatter.usesGroupingSeparator = true
      formatter.numberStyle = .percent
      formatter.locale = locale
      formatter.minimumFractionDigits = 0
      self.formatted = formatter.string(from: value as NSDecimalNumber)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case formatted
    case value
    case format
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(formatted, forKey: .formatted)
    // Note: price is encoded price as `String` (using `NSDecimalNumber.description`)
    // to preserve precision and avoid values like "1.89999999"
    try container.encode(self.value.description, forKey: .value)
    try container.encode(self.format, forKey: .format)
  }
}
