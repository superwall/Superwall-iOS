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

  func syncSubscriptionStatus(
    withPurchases purchases: Set<Purchase>,
    superwall: Superwall? = nil
  ) async {
    let activePurchases = purchases.filter { $0.isActive }
    var entitlements: Set<Entitlement> = []

    for activePurchase in activePurchases {
      let purchaseEntitlements = entitlementsInfo.byProductId(activePurchase.id)
      entitlements = entitlements.union(purchaseEntitlements)
    }

    await MainActor.run { [entitlements] in
      let superwall = superwall ?? Superwall.shared
      if entitlements.isEmpty {
        // An empty device read is not proof that the user lost access. StoreKit
        // can return nothing at cold launch before it hydrates, and web/Stripe
        // subscribers never have App Store purchases. Keep an `.active` status
        // while one of its entitlements is still within its expiry date.
        // Entitlements with no expiry date don't hold the status, so a revoked
        // lifetime purchase can still deactivate here.
        if case .active(let currentEntitlements) = superwall.subscriptionStatus,
          currentEntitlements.contains(where: { ($0.expiresAt ?? .distantPast) > Date() }) {
          return
        }
        superwall.internallySetSubscriptionStatus(to: .inactive, superwall: superwall)
      } else {
        superwall.internallySetSubscriptionStatus(to: .active(entitlements), superwall: superwall)
      }
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
      await factory.loadPurchasedProducts(config: nil)
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
  func syncSubscriptionStatus(purchases: Set<Purchase>) async {
    await syncSubscriptionStatus(withPurchases: purchases)
  }
}
