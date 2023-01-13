//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/01/2023.
//

import Foundation
import StoreKit

final class SKProductSubscriptionPeriodMock: SKProductSubscriptionPeriod {
  override var numberOfUnits: Int {
    return 1
  }
}
