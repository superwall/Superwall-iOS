//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 27/03/2025.
//

import Foundation
@testable import SuperwallKit

final class MockExternalPurchaseControllerFactory: HasExternalPurchaseControllerFactory {
  let purchaseController: PurchaseController

  init(purchaseController: PurchaseController) {
    self.purchaseController = purchaseController
  }

  func makeExternalPurchaseController() -> any PurchaseController {
    return purchaseController
  }

  func makeHasExternalPurchaseController() -> Bool {
    return true
  }
}
