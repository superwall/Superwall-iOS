//
//  SWProductNumber.swift
//  Superwall
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

    try container.encodeIfPresent(formatted, forKey: .formatted)
    // Note: value is price encoded as `String` (using `NSDecimalNumber.description`)
    // to preserve precision and avoid values like "1.89999999"
    try container.encode(self.value.description, forKey: .value)
    try container.encode(self.format, forKey: .format)
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    format = try values.decode(Format.self, forKey: .format)
    formatted = try values.decodeIfPresent(String.self, forKey: .formatted)
    let stringValue = try values.decode(String.self, forKey: .value)
    value = Decimal(string: stringValue) ?? 0
  }
}
