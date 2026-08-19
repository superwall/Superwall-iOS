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

    let activeProductIds = Set(activePurchases.map { $0.id })

    await MainActor.run { [entitlements] in
      let superwall = superwall ?? Superwall.shared
      if entitlements.isEmpty {
        // A device read with no entitlements can mean different things,
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
        // - A purchase is still active but maps to no entitlement: a
        //   mapping failure (the config no longer knows the product), not
        //   an authoritative answer for the entitlement it unlocks.
        //
        // On a non-answer, keep an `.active` status while one of its
        // entitlements is within its expiry date. A device read also has no
        // authority over entitlements not granted by the App Store, so those
        // hold the status even when unrelated inactive purchases exist. A
        // nil store means no App Store transaction unlocks the entitlement
        // (web or manual grant — both receipt managers stamp `.appStore` on
        // entitlements a receipt transaction unlocks, so active
        // device-derived entitlements always carry it), so nil is protected
        // too. Entitlements with no expiry date never hold the status, so a
        // revoked lifetime purchase can still deactivate here.
        if case .active(let currentEntitlements) = superwall.subscriptionStatus {
          let holdsStatus = currentEntitlements.contains { entitlement in
            guard entitlement.isActive,
              (entitlement.expiresAt ?? .distantPast) > Date() else {
              return false
            }
            if purchases.isEmpty || entitlement.store != .appStore {
              return true
            }
            // A still-active purchase that unlocks this entitlement means
            // the empty entitlement set is a mapping failure, so the read
            // cannot refute the entitlement it just confirmed.
            return entitlement.productIds.contains { activeProductIds.contains($0) }
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
