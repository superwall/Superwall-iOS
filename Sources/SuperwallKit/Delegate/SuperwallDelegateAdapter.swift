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
      objcDelegate.willDismissPaywall?()
    }
  }

  @MainActor
  func willPresentPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willPresentPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willPresentPaywall?()
    }
  }

  @MainActor
  func didDismissPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didDismissPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didDismissPaywall?()
    }
  }

  @MainActor
  func didPresentPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didPresentPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didPresentPaywall?()
    }
  }

  @MainActor
  func willOpenURL(url: URL) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willOpenURL(url: url)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willOpenURL?(url: url)
    }
  }

  @MainActor
  func willOpenDeepLink(url: URL) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willOpenDeepLink(url: url)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willOpenDeepLink?(url: url)
    }
  }

  @MainActor
  func didTrackSuperwallEventInfo(_ info: SuperwallEventInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didTrackSuperwallEventInfo(info)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didTrackSuperwallEventInfo?(info)
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
  func restorePurchases() async -> Bool {
    var didRestore = false
    if let purchaseController = swiftPurchaseController {
      didRestore = await purchaseController.restorePurchases()
    } else if let purchaseController = objcPurchaseController {
      didRestore = await withCheckedContinuation { continuation in
        purchaseController.restorePurchases { didRestore in
          continuation.resume(returning: didRestore)
        }
      }
    }
    return didRestore
  }
}
