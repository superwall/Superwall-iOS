//
//  SWProductNumberGroup.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

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
