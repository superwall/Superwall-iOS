//
//  PriceTemplateVariable.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct SWPriceTemplateVariable: Codable {
  var `default`: SWProductNumberGroup?
  var daily: SWProductNumberGroup?
  var weekly: SWProductNumberGroup?
  var monthly: SWProductNumberGroup?
  var quarterly: SWProductNumberGroup?
  var yearly: SWProductNumberGroup?

  var raw: SWProductNumber?
  var pretty: SWProductNumber?
  var rounded: SWProductNumber?

  init(
    value: Decimal,
    locale: Locale,
    period: SWProductSubscriptionPeriod?
  ) {
    if let period = period {
      self.default = SWProductNumberGroup(
        value: period.price(for: value, in: period.colloquialUnit),
        format: .currency,
        locale: locale
      )
      self.daily = SWProductNumberGroup(
        value: period.price(for: value, in: .days),
        format: .currency,
        locale: locale
      )
      self.weekly = SWProductNumberGroup(
        value: period.price(for: value, in: .weeks),
        format: .currency,
        locale: locale
      )
      self.monthly = SWProductNumberGroup(
        value: period.price(for: value, in: .months),
        format: .currency,
        locale: locale
      )
      self.quarterly = SWProductNumberGroup(
        value: period.price(for: value, in: .quarters),
        format: .currency,
        locale: locale
      )
      self.yearly = SWProductNumberGroup(
        value: period.price(for: value, in: .years),
        format: .currency,
        locale: locale
      )
    } else {
      let numberGroup = SWProductNumberGroup(
        value: value,
        format: .currency,
        locale: locale
      )
      self.raw = numberGroup.raw
      self.pretty = numberGroup.pretty
      self.rounded = numberGroup.rounded
    }
  }
}
