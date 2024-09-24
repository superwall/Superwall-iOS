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
  private unowned let entitlementsInfo: EntitlementsInfo

  init(
    factory: ReceiptFactory & PurchasedTransactionsFactory,
    entitlementsInfo: EntitlementsInfo
  ) {
    self.factory = factory
    self.entitlementsInfo = entitlementsInfo
  }

  func syncEntitlements(withPurchases purchases: Set<Purchase>) async {
    let activePurchases = purchases.filter { $0.isActive }
    var entitlements: Set<Entitlement> = []

    for activePurchase in activePurchases {
      let purchaseEntitlements = entitlementsInfo.byProductId(activePurchase.id)
      entitlements = entitlements.union(purchaseEntitlements)
    }

    // If they haven't changed, don't disturb main thread.
    if
      Superwall.shared.entitlements.didSetActiveEntitlements,
      entitlements == Superwall.shared.entitlements.active {
      return
    }

    await MainActor.run { [entitlements] in
      Superwall.shared.entitlements.set(entitlements)
    }
  }
}

// MARK: - PurchaseController

extension AutomaticPurchaseController: PurchaseController {
  @MainActor
  func purchase(product: StoreProduct) async -> PurchaseResult {
    return await factory.purchase(product: product)
  }

  @MainActor
  func restorePurchases() async -> RestorationResult {
    let result = await factory.restorePurchases()

    let hasRestored = result == .restored
    await factory.refreshSK1Receipt()
    if hasRestored {
      await factory.loadPurchasedProducts()
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
  func syncEntitlements(purchases: Set<Purchase>) async {
    await syncEntitlements(withPurchases: purchases)
  }
}
