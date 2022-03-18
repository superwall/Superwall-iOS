//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/03/2022.
//

import StoreKit

class MockProduct: SKProduct {
  var testIntroPeriod: MockIntroductoryPeriod

  override var introductoryPrice: SKProductDiscount? {
    return testIntroPeriod
  }

  init(testIntroPeriod: MockIntroductoryPeriod) {
    self.testIntroPeriod = testIntroPeriod
  }
}
