//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/08/2023.
//

import Foundation
import StoreKit

final class InternalPurchaseController {
  var isDeveloperProvided: Bool {
    return swiftPurchaseController != nil || objcPurchaseController != nil
  }
  private var swiftPurchaseController: PurchaseController?
  private var objcPurchaseController: PurchaseControllerObjc?
  lazy var productPurchaser = factory.makeSK1ProductPurchaser()
  private let factory: ProductPurchaserFactory

  init(
    factory: ProductPurchaserFactory,
    swiftPurchaseController: PurchaseController?,
    objcPurchaseController: PurchaseControllerObjc?
  ) {
    self.swiftPurchaseController = swiftPurchaseController
    self.objcPurchaseController = objcPurchaseController
    self.factory = factory
  }
}

  // MARK: - Purchase Controller
extension InternalPurchaseController: PurchaseController {
  func purchase(product: SKProduct) async -> PurchaseResult {
    // TODO: CHeck this is actually on mainactor
    if let purchaseController = swiftPurchaseController {
      return await purchaseController.purchase(product: product)
    } else if let purchaseController = objcPurchaseController {
      return await withCheckedContinuation { continuation in
        purchaseController.purchase(product: product) { result, error in
          if let error = error {
            continuation.resume(returning: .failed(error))
          } else {
            switch result {
            case .purchased:
              continuation.resume(returning: .purchased)
            case .pending:
              continuation.resume(returning: .pending)
            case .cancelled:
              continuation.resume(returning: .cancelled)
            case .failed:
              break
            }
          }
        }
      }
    } else {
      return await productPurchaser.purchase(product: product)
    }
  }

  func restorePurchases() async -> RestorationResult {
    if let purchaseController = swiftPurchaseController {
      return await purchaseController.restorePurchases()
    } else if let purchaseController = objcPurchaseController {
      return await withCheckedContinuation { continuation in
        purchaseController.restorePurchases { result, error in
          switch result {
          case .restored:
            continuation.resume(returning: .restored)
          case .failed:
            continuation.resume(returning: .failed(error))
          }
        }
      }
    } else {
      return await productPurchaser.restorePurchases()
    }
  }
}
