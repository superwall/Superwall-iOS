//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/10/2022.
//

import Foundation
import Combine

/// An adapter between the internal SDK and the public swift/objective c delegate.
final class SuperwallDelegateAdapter {
  var hasPurchaseController: Bool {
    return swiftPurchaseController != nil || objcPurchaseController != nil
  }
  weak var swiftDelegate: SuperwallDelegate?
  weak var objcDelegate: SuperwallDelegateObjc?
  weak var swiftPurchaseController: PurchaseController?
  weak var objcPurchaseController: PurchaseControllerObjc?

  /// Called on init of the Superwall instance via ``Superwall/configure(apiKey:purchaseController:options:completion:)-52tke``.
  init(
    swiftPurchaseController: PurchaseController?,
    objcPurchaseController: PurchaseControllerObjc?
  ) {
    self.swiftPurchaseController = swiftPurchaseController
    self.objcPurchaseController = objcPurchaseController
  }

  @MainActor
  func handleCustomPaywallAction(withName name: String) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.handleCustomPaywallAction(withName: name)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.handleCustomPaywallAction?(withName: name)
    }
  }

  @MainActor
  func willDismissPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willDismissPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willDismissPaywall?(withInfo: paywallInfo)
    }
  }

  @MainActor
  func willPresentPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willPresentPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willPresentPaywall?(withInfo: paywallInfo)
    }
  }

  @MainActor
  func didDismissPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didDismissPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didDismissPaywall?(withInfo: paywallInfo)
    }
  }

  @MainActor
  func didPresentPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didPresentPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didPresentPaywall?(withInfo: paywallInfo)
    }
  }

  @MainActor
  func paywallWillOpenURL(url: URL) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.paywallWillOpenURL(url: url)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.paywallWillOpenURL?(url: url)
    }
  }

  @MainActor
  func paywallWillOpenDeepLink(url: URL) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.paywallWillOpenDeepLink(url: url)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.paywallWillOpenDeepLink?(url: url)
    }
  }

  @MainActor
  func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.handleSuperwallEvent(withInfo: eventInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.handleSuperwallEvent?(withInfo: eventInfo)
    }
  }

  func subscriptionStatusDidChange(to newValue: SubscriptionStatus) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.subscriptionStatusDidChange(to: newValue)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.subscriptionStatusDidChange?(to: newValue)
    }
  }

  @MainActor
  func handleLog(
    level: String,
    scope: String,
    message: String?,
    info: [String: Any]?,
    error: Swift.Error?
  ) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.handleLog(
        level: level,
        scope: scope,
        message: message,
        info: info,
        error: error
      )
    } else if let objcDelegate = objcDelegate {
      objcDelegate.handleLog?(
        level: level,
        scope: scope,
        message: message,
        info: info,
        error: error
      )
    }
  }
}

// MARK: - Product Purchaser
extension SuperwallDelegateAdapter: ProductPurchaser {
  @MainActor
  func purchase(
    product: StoreProduct
  ) async -> PurchaseResult {
    if let purchaseController = swiftPurchaseController {
      guard let sk1Product = product.sk1Product else {
        return .failed(PurchaseError.productUnavailable)
      }
      return await purchaseController.purchase(product: sk1Product)
    } else if let purchaseController = objcPurchaseController {
      guard let sk1Product = product.sk1Product else {
        return .failed(PurchaseError.productUnavailable)
      }
      return await withCheckedContinuation { continuation in
        purchaseController.purchase(product: sk1Product) { result, error in
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
    }
    return .cancelled
  }
}

// MARK: - TransactionRestorer
extension SuperwallDelegateAdapter: TransactionRestorer {
  @MainActor
  func restorePurchases() async -> RestorationResult {
    if let purchaseController = swiftPurchaseController {
      let result = await purchaseController.restorePurchases()
      return result
    } else if let purchaseController = objcPurchaseController {
      let (result, error) = await withCheckedContinuation { continuation in
        purchaseController.restorePurchases { (result, error) in
          continuation.resume(returning: (result, error))
        }
      }
      let swiftResult: RestorationResult = result == .restored ? .restored : .failed(error)
      return swiftResult
    }
    // wont get here
    return .failed(nil)
  }
}
