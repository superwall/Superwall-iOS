//
//  AutomaticPurchaseController.swift
//
//
//  Created by Yusuf Tör on 29/08/2023.
//

import Foundation
import StoreKit

final class AutomaticPurchaseController {
  private let factory: ReceiptFactory & PurchasedTransactionsFactory

  init(factory: ReceiptFactory & PurchasedTransactionsFactory) {
    self.factory = factory
  }

  func syncSubscriptionStatus(withPurchases purchases: Set<InAppPurchase>) async {
    let activePurchases = purchases.filter { $0.isActive }
    await MainActor.run {
      if activePurchases.isEmpty {
        Superwall.shared.subscriptionStatus = .inactive
      } else {
        Superwall.shared.subscriptionStatus = .active
      }
    }
  }
}

// MARK: - PurchaseController

extension AutomaticPurchaseController: PurchaseController {
  @MainActor
  func purchase(product: SKProduct) async -> PurchaseResult {
    return await factory.purchase(
      product: product,
      isExternal: false
    )
  }

  @MainActor
  func restorePurchases() async -> RestorationResult {
    let result = await factory.restorePurchases(isExternal: false)

    let hasRestored = result == .restored
    await factory.refreshReceipt()
    if hasRestored {
      _ = await factory.loadPurchasedProducts()
    }

    return result
  }
}

// MARK: - InternalPurchaseController

extension AutomaticPurchaseController: InternalPurchaseController {
  var isInternal: Bool { return true }
}

// MARK: - ReceiptDelegate

extension AutomaticPurchaseController: ReceiptDelegate {
  func receiptLoaded(purchases: Set<InAppPurchase>) async {
    await syncSubscriptionStatus(withPurchases: purchases)
  }
}
