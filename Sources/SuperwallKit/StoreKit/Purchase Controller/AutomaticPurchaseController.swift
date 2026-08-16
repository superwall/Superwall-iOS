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
        // A device read with no entitlements can mean two different things,
        // and only one of them may demote a subscriber:
        //
        // - Purchases exist but none is active: an authoritative answer.
        //   Refunded and expired transactions stay in the set as inactive
        //   (SK2 reads `Transaction.all`; the SK1 receipt keeps cancelled
        //   purchases), so this downgrades immediately.
        // - The purchases set is completely empty: a non-answer. StoreKit
        //   returns nothing at cold launch before it hydrates, the SK1
        //   receipt can be missing, and web/Stripe subscribers have no App
        //   Store purchases at all.
        //
        // On a non-answer, keep an `.active` status while one of its
        // entitlements is within its expiry date. A device read also has no
        // authority over entitlements from other stores (Stripe, web), so
        // those hold the status even when unrelated inactive purchases
        // exist. Entitlements with no expiry date never hold the status, so
        // a revoked lifetime purchase can still deactivate here.
        if case .active(let currentEntitlements) = superwall.subscriptionStatus {
          let holdsStatus = currentEntitlements.contains { entitlement in
            guard entitlement.isActive,
              (entitlement.expiresAt ?? .distantPast) > Date() else {
              return false
            }
            if purchases.isEmpty {
              return true
            }
            if let store = entitlement.store, store != .appStore {
              return true
            }
            return false
          }
          if holdsStatus {
            return
          }
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
