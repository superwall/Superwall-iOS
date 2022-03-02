//
//  ProductPeriod.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct SWProductPeriod: Codable {
  var full: String?
  var short: String?
  var abbreviated: String?
  var duration: SWProductNumberGroup?

  init(
    units: SWProductSubscriptionPeriod.ColloquialUnit,
    period: SWProductSubscriptionPeriod,
    locale: Locale
  ) {
    self.full = period.period(in: units, unitsStyle: .full)
    self.short = period.period(in: units, unitsStyle: .short)
    self.abbreviated = period.period(in: units, unitsStyle: .abbreviated)
    self.duration = SWProductNumberGroup(value: period.numberOfUnits(in: units), format: .number, locale: locale)
  }
}

struct SWPeriodTemplateVariable: Codable {
  var `default`: SWProductPeriod
  var daily: SWProductPeriod
  var weekly: SWProductPeriod
  var monthly: SWProductPeriod
  var quarterly: SWProductPeriod
  var yearly: SWProductPeriod

  init(
    period: SWProductSubscriptionPeriod,
    locale: Locale
  ) {
    self.default = SWProductPeriod(units: period.colloquialUnit, period: period, locale: locale)
    self.daily = SWProductPeriod(units: .days, period: period, locale: locale)
    self.weekly = SWProductPeriod(units: .weeks, period: period, locale: locale)
    self.monthly = SWProductPeriod(units: .months, period: period, locale: locale)
    self.quarterly = SWProductPeriod(units: .quarters, period: period, locale: locale)
    self.yearly = SWProductPeriod(units: .years, period: period, locale: locale)
  }
}
