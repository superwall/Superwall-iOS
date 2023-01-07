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
  var hasSubscriptionController: Bool {
    return swiftDelegate?.subscriptionController() != nil
      || objcDelegate?.subscriptionController?() != nil
  }
  weak var swiftDelegate: SuperwallDelegate?
  weak var objcDelegate: SuperwallDelegateObjc?

/// Called on init of the Superwall instance via ``SuperwallKit/Superwall/configure(apiKey:delegate:options:)-7doe5``.
  ///
  /// We check to see if the delegates being set are non-nil because they may have been set
  /// separately to the initial Superwall.config function.
  init(
    swiftDelegate: SuperwallDelegate?,
    objcDelegate: SuperwallDelegateObjc?
  ) {
    self.swiftDelegate = swiftDelegate
    self.objcDelegate = objcDelegate
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
  func willDismissPaywall() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willDismissPaywall()
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willDismissPaywall?()
    }
  }

  @MainActor
  func willPresentPaywall() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willPresentPaywall()
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willPresentPaywall?()
    }
  }

  @MainActor
  func didDismissPaywall() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didDismissPaywall()
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didDismissPaywall?()
    }
  }

  @MainActor
  func didPresentPaywall() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didPresentPaywall()
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

// MARK: - User Subscription Handling
extension SuperwallDelegateAdapter: SubscriptionStatusChecker {
  @MainActor
  func isSubscribed() -> Bool {
    if let swiftDelegate = swiftDelegate {
      guard let subscriptionController = swiftDelegate.subscriptionController() else {
        return false
      }
      return subscriptionController.isUserSubscribed()
    } else if let objcDelegate = objcDelegate {
      guard let subscriptionController = objcDelegate.subscriptionController?() else {
        return false
      }
      return subscriptionController.isUserSubscribed()
    }
    return false
  }
}

// MARK: - Product Purchaser
extension SuperwallDelegateAdapter: ProductPurchaser {
  @MainActor
  func purchase(
    product: StoreProduct
  ) async -> PurchaseResult {
    if let swiftDelegate = swiftDelegate {
      guard let subscriptionController = swiftDelegate.subscriptionController() else {
        return .cancelled
      }
      return await subscriptionController.purchase(product: product.underlyingSK1Product)
    } else if let objcDelegate = objcDelegate {
      guard let subscriptionController = objcDelegate.subscriptionController?() else {
        return .cancelled
      }
      return await withCheckedContinuation { continuation in
        subscriptionController.purchase(product: product.underlyingSK1Product) { result, error in
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
    if let swiftDelegate = swiftDelegate {
      guard let subscriptionController = swiftDelegate.subscriptionController() else {
        return false
      }
      didRestore = await subscriptionController.restorePurchases()
    } else if let objcDelegate = objcDelegate {
      guard let subscriptionController = objcDelegate.subscriptionController?() else {
        return false
      }
      didRestore = await withCheckedContinuation { continuation in
        subscriptionController.restorePurchases { didRestore in
          continuation.resume(returning: didRestore)
        }
      }
    }
    return didRestore
  }
}
