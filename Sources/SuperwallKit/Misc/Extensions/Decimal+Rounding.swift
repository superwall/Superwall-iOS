//
//  Decimal+Rounding.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

extension Decimal {
  mutating func round(
    _ scale: Int,
    _ roundingMode: NSDecimalNumber.RoundingMode
  ) {
    var initialDecimal = self
    NSDecimalRound(&self, &initialDecimal, scale, roundingMode)
  }

  func rounded(
    _ scale: Int,
    _ roundingMode: NSDecimalNumber.RoundingMode
  ) -> Decimal {
    var roundedDecimal = Decimal()
    var initialDecimal = self
    NSDecimalRound(&roundedDecimal, &initialDecimal, scale, roundingMode)
    return roundedDecimal
  }
}
