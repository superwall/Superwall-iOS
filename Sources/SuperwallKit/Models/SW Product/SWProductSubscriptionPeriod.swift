//
//  SWProductSubscriptionPeriod.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import StoreKit

struct SWProductSubscriptionPeriod: Codable {
  enum Unit: String, Codable {
    case day
    case week
    case month
    case year
    case unknown
  }

  enum ColloquialUnit: String, Codable {
    case days
    case weeks
    case months
    case quarters
    case years
  }

  var numberOfUnits: Int

  var unit: SWProductSubscriptionPeriod.Unit

  var colloquialUnit: ColloquialUnit {
    if numberOfUnits(in: .days) == 1 {
      return .days
    }

    if numberOfUnits(in: .weeks) == 1 {
      return .weeks
    }

    if numberOfUnits(in: .months) == 1 {
      return .months
    }

    if numberOfUnits(in: .quarters) == 1 {
      return .quarters
    }

    if numberOfUnits(in: .years) == 1 {
      return .years
    }

    switch unit {
    case .day:
      return .days
    case .week:
      return .weeks
    case .month:
      return .months
    case .year:
      return .years
    case .unknown:
      return .months
    }
  }

  init(period: SKProductSubscriptionPeriod, numberOfPeriods: Int) {
    self.numberOfUnits = period.numberOfUnits * numberOfPeriods
    switch period.unit {
    case .day:
      self.unit = .day
    case .week:
      self.unit = .week
    case .month:
      self.unit = .month
    case .year:
      self.unit = .year
    @unknown default:
      self.unit = .unknown
    }
  }

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  init(period: StoreKit.Product.SubscriptionPeriod, numberOfPeriods: Int) {
    self.numberOfUnits = period.value * numberOfPeriods
    switch period.unit {
    case .day:
      self.unit = .day
    case .week:
      self.unit = .week
    case .month:
      self.unit = .month
    case .year:
      self.unit = .year
    @unknown default:
      self.unit = .unknown
    }
  }

  var numberOfUnitsDouble: Double {
    return Double(numberOfUnits)
  }

  var daysPerUnit: Double {
    switch unit {
    case .day:
      return 1
    case .week:
      return 7
    case .month:
      return 30
    case .year:
      return 365
    case .unknown:
      return 1
    }
  }

  var weeksPerUnit: Double {
    switch unit {
    case .day:
      return 1.0 / 7
    case .week:
      return 1
    case .month:
      return 4
    case .year:
      return 52
    case .unknown:
      return 1
    }
  }

  var monthsPerUnit: Double {
    switch unit {
    case .day:
      return 1.0 / 30
    case .week:
      return 1.0 / 4
    case .month:
      return 1
    case .year:
      return 12
    case .unknown:
      return 1
    }
  }

  var quartersPerUnit: Double {
    switch unit {
    case .day:
      return 1.0 / 91.25
    case .week:
      return 1.0 / 13.0
    case .month:
      return 1.0 / 3.0
    case .year:
      return 4
    case .unknown:
      return 1
    }
  }

  var yearsPerUnit: Double {
    switch unit {
    case .day:
      return 1.0 / 365
    case .week:
      return 1.0 / 52.0
    case .month:
      return 1.0 / 12.0
    case .year:
      return 1
    case .unknown:
      return 1
    }
  }

  func numberOfUnits(in cUnit: ColloquialUnit) -> Decimal {
    switch cUnit {
    case .days:
      return Decimal(daysPerUnit * numberOfUnitsDouble)
    case .weeks:
      return Decimal(weeksPerUnit * numberOfUnitsDouble)
    case .months:
      return Decimal(monthsPerUnit * numberOfUnitsDouble)
    case .quarters:
      return Decimal(quartersPerUnit * numberOfUnitsDouble)
    case .years:
      return Decimal(yearsPerUnit * numberOfUnitsDouble)
    }
  }

  func numberOfUnits(in cUnit: ColloquialUnit) -> Double {
    switch cUnit {
    case .days:
      return daysPerUnit * numberOfUnitsDouble
    case .weeks:
      return weeksPerUnit * numberOfUnitsDouble
    case .months:
      return monthsPerUnit * numberOfUnitsDouble
    case .quarters:
      return quartersPerUnit * numberOfUnitsDouble
    case .years:
      return yearsPerUnit * numberOfUnitsDouble
    }
  }

  func numberOfUnits(in cUnit: ColloquialUnit) -> Int {
    switch cUnit {
    case .days:
      return Int(round(daysPerUnit * numberOfUnitsDouble))
    case .weeks:
      return Int(round(weeksPerUnit * numberOfUnitsDouble))
    case .months:
      return Int(round(monthsPerUnit * numberOfUnitsDouble))
    case .quarters:
      return Int(round(quartersPerUnit * numberOfUnitsDouble))
    case .years:
      return Int(round(yearsPerUnit * numberOfUnitsDouble))
    }
  }

  func price(for value: Decimal, in cUnit: ColloquialUnit) -> Decimal {
    let units: Decimal = numberOfUnits(in: cUnit)
    return value / units
  }

  func string(for cUnit: ColloquialUnit, unitsStyle: DateComponentsFormatter.UnitsStyle) -> String? {
    let formatter = DateComponentsFormatter()
    formatter.allowsFractionalUnits = true
    formatter.unitsStyle = unitsStyle
    let numberOfUnits: Int = numberOfUnits(in: .days)

    switch cUnit {
    case .days:
      formatter.allowedUnits = [.day]
      return formatter.string(from: DateComponents(day: numberOfUnits))
    case .weeks:
      formatter.allowedUnits = [.weekOfMonth]
      return formatter.string(from: DateComponents(day: numberOfUnits))
    case .months:
      formatter.allowedUnits = [.month]
      return formatter.string(from: DateComponents(day: numberOfUnits))
    case .quarters:
      let numberFormatter = NumberFormatter()
      numberFormatter.maximumFractionDigits = 2
      numberFormatter.minimumFractionDigits = 0

      let numberOfQuarters: Double = self.numberOfUnits(in: .quarters)
      if let quarters = numberFormatter.string(from: NSNumber(value: numberOfQuarters)) {
        return numberOfQuarters == 1.0 ? "\(numberOfUnits) quarter" : "\(quarters) quarters"
      } else {
        return numberOfQuarters == 1.0 ? "\(numberOfUnits) quarter" : "\(numberOfUnits) quarters"
      }
    case .years:
      formatter.allowedUnits = [.year]
      return formatter.string(from: DateComponents(day: numberOfUnits))
    }
  }

  func unit(from: String) -> String {
    let forbidden = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
    return from
      .removeCharacters(from: forbidden)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func period(in cUnit: ColloquialUnit, unitsStyle: DateComponentsFormatter.UnitsStyle) -> String? {
    if numberOfUnits(in: cUnit) == 1 {
      return unitString(for: cUnit, unitsStyle: unitsStyle)
    } else {
      return string(for: cUnit, unitsStyle: unitsStyle)
    }
  }

  func unitString(for cUnit: ColloquialUnit, unitsStyle: DateComponentsFormatter.UnitsStyle) -> String? {
    if let string = string(for: cUnit, unitsStyle: unitsStyle) {
      return unit(from: string)
    }

    return nil
  }
}
