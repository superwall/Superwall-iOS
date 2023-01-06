//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/10/2022.
//

import Foundation
import Combine

/// An adapter between the internal SDK and the public swift/objective c delegate.
final class SuperwallPurchasingDelegateAdapter {
  var hasDelegate: Bool {
    return swiftDelegate != nil || objcDelegate != nil
  }
  weak var swiftDelegate: SuperwallPurchasingDelegate?
  weak var objcDelegate: SuperwallPurchasingDelegateObjc?
  unowned let storeKitManager: StoreKitManager

/// Called on init of the Superwall instance via ``SuperwallKit/Superwall/configure(apiKey:delegate:options:)-7doe5``.
  ///
  /// We check to see if the delegates being set are non-nil because they may have been set
  /// separately to the initial Superwall.config function.
  init(
    swiftDelegate: SuperwallPurchasingDelegate?,
    objcDelegate: SuperwallPurchasingDelegateObjc?,
    storeKitManager: StoreKitManager
  ) {
    self.swiftDelegate = swiftDelegate
    self.objcDelegate = objcDelegate
    self.storeKitManager = storeKitManager
  }
}

// MARK: - User Subscription Handling
extension SuperwallPurchasingDelegateAdapter: SubscriptionStatusChecker {
  @MainActor
  func isSubscribed() -> Bool {
    if let swiftDelegate = swiftDelegate {
      return swiftDelegate.isUserSubscribed()
    } else if let objcDelegate = objcDelegate {
      return objcDelegate.isUserSubscribed()
    }
    return false
  }
}

// MARK: - Product Purchaser
extension SuperwallPurchasingDelegateAdapter: ProductPurchaser {
  @MainActor
  func purchase(
    product: StoreProduct
  ) async -> PurchaseResult {
    if let swiftDelegate = swiftDelegate {
      return await swiftDelegate.purchase(product: product.underlyingSK1Product)
    } else if let objcDelegate = objcDelegate {
      return await withCheckedContinuation { continuation in
        objcDelegate.purchase(product: product.underlyingSK1Product) { result, error in
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
extension SuperwallPurchasingDelegateAdapter: TransactionRestorer {
  @MainActor
  func restorePurchases() async -> Bool {
    var didRestore = false
    if let swiftDelegate = swiftDelegate {
      didRestore = await swiftDelegate.restorePurchases()
    } else if let objcDelegate = objcDelegate {
      didRestore = await withCheckedContinuation { continuation in
        objcDelegate.restorePurchases { didRestore in
          continuation.resume(returning: didRestore)
        }
      }
    }
    
    // They may have refreshed the receipt themselves, but this is just
    // incase...
    await storeKitManager.refreshReceipt()
    return didRestore
  }
}
