//
//  Decimal+Rounding.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

extension Decimal {
  mutating func round(
    _ scale: Int,
    _ roundingMode: NSDecimalNumber.RoundingMode
  ) {
    var localCopy = self
    NSDecimalRound(&self, &localCopy, scale, roundingMode)
  }

  func rounded(
    _ scale: Int,
    _ roundingMode: NSDecimalNumber.RoundingMode
  ) -> Decimal {
    var result = Decimal()
    var localCopy = self
    NSDecimalRound(&result, &localCopy, scale, roundingMode)
    return result
  }
}
