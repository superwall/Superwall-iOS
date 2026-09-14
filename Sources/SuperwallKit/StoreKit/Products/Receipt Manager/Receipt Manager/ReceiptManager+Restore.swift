//
//  ReceiptManager+Restore.swift
//  SuperwallKit
//

import Foundation

// MARK: - Restoring from the previous launch

extension ReceiptManager {
  /// Rebuilds the in-memory purchase state from the customer info saved by the
  /// previous launch, so config can be published before this launch's StoreKit
  /// read finishes. `loadPurchasedProducts` overwrites all of it when it lands.
  ///
  /// Each saved item carries its own expiry, which the store asserted, so
  /// anything past it has lapsed since the last launch and is restored inactive.
  func restorePurchases(from customerInfo: CustomerInfo, config: Config) async {
    let now = Date()
    let activeSubscriptions = customerInfo.subscriptions.filter {
      $0.isActive && !hasExpired($0.expirationDate, at: now)
    }
    let subscriptionPurchases = customerInfo.subscriptions.map { subscription in
      Purchase(
        id: subscription.productId,
        isActive: activeSubscriptions.contains { $0 === subscription },
        purchaseDate: subscription.purchaseDate
      )
    }
    let nonSubscriptionPurchases = customerInfo.nonSubscriptions.map {
      Purchase(id: $0.productId, isActive: !$0.isRevoked, purchaseDate: $0.purchaseDate)
    }
    let purchases = Set(subscriptionPurchases + nonSubscriptionPurchases)
    await manager.seedPurchases(purchases)

    // Config knows every product and the entitlements it unlocks. The saved
    // customer info knows which of those were active, and carries fields like
    // willRenew that audience filters read, so its copy wins where both have one.
    let savedById = Dictionary(
      customerInfo.entitlements.map { entitlement in
        let lapsed = entitlement.isActive && hasExpired(entitlement.expiresAt, at: now)
        return (entitlement.id, lapsed ? deactivated(entitlement) : entitlement)
      }
    ) { $1 }
    let entitlementsByProductId = ConfigLogic.extractEntitlements(from: config)
      .mapValues { Set($0.map { savedById[$0.id] ?? $0 }) }
    Superwall.shared.entitlements.setEntitlementsFromConfig(entitlementsByProductId)

    activeSubscriptionGroupIds = Set(activeSubscriptions.compactMap { $0.subscriptionGroupId })
  }

  /// A nil expiry never lapses: lifetime purchases and web entitlements without one.
  private func hasExpired(_ expiresAt: Date?, at now: Date) -> Bool {
    guard let expiresAt = expiresAt else {
      return false
    }
    return expiresAt <= now
  }

  private func deactivated(_ entitlement: Entitlement) -> Entitlement {
    return Entitlement(
      id: entitlement.id,
      type: entitlement.type,
      isActive: false,
      productIds: entitlement.productIds,
      latestProductId: entitlement.latestProductId,
      store: entitlement.store,
      startsAt: entitlement.startsAt,
      renewedAt: entitlement.renewedAt,
      expiresAt: entitlement.expiresAt,
      isLifetime: entitlement.isLifetime,
      willRenew: entitlement.willRenew,
      state: entitlement.state,
      offerType: entitlement.offerType
    )
  }
}
