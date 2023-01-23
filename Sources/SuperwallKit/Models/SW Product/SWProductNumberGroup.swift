//
//  SWProductNumberGroup.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct SWProductNumberGroup: Encodable {
  var raw: SWProductNumber?
  var pretty: SWProductNumber?
  var rounded: SWProductNumber?

  init(value: Decimal, format: SWProductNumber.Format, locale: Locale) {
    let roundedValue = (value * 100).rounded(0, .plain) / 100
    var prettyValue = (value / 0.05).rounded(0, .plain) * 0.05

    if format == .currency {
      prettyValue = (value / 0.1).rounded(0, .plain) * 0.1 - 0.01
    }

    self.raw = SWProductNumber(value: value, format: format, locale: locale)
    self.rounded = SWProductNumber(value: roundedValue, format: format, locale: locale)
    self.pretty = SWProductNumber(value: prettyValue, format: format, locale: locale)
  }
}
