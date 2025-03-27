//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 27/03/2025.
//

import Foundation
@testable import SuperwallKit

final class MockPurchaseController: PurchaseController {
  var didCallOffDeviceSubscriptionsDidChange = false

  func purchase(product: SuperwallKit.StoreProduct) async -> SuperwallKit.PurchaseResult {
    return .purchased
  }
  
  func restorePurchases() async -> SuperwallKit.RestorationResult {
    return .restored
  }

  func offDeviceSubscriptionsDidChange(entitlements: Set<Entitlement>) async {
    didCallOffDeviceSubscriptionsDidChange = true
  }
}
