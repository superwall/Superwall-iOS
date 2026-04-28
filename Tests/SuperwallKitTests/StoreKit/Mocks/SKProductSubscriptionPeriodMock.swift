//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/01/2023.
//

import Foundation
import StoreKit

final class SKProductSubscriptionPeriodMock: SKProductSubscriptionPeriod {
  private let internalNumberOfUnits: Int
  private let internalUnit: SKProduct.PeriodUnit

  override var numberOfUnits: Int {
    return internalNumberOfUnits
  }

  override var unit: SKProduct.PeriodUnit {
    return internalUnit
  }

  init(
    numberOfUnits: Int = 1,
    unit: SKProduct.PeriodUnit = .month
  ) {
    self.internalNumberOfUnits = numberOfUnits
    self.internalUnit = unit
  }
}
