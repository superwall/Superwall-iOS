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
  /// A nil expiry keeps its saved state, except on a subscription: nothing can
  /// show one is still current, so it isn't restored active.
  func restorePurchases(
    from customerInfo: CustomerInfo,
    grantedEntitlements: Set<Entitlement>,
    config: Config
  ) async {
    let now = Date()
    // The saved copy is the merged one, with web subscriptions appended. The
    // purchases the StoreKit 2 read produces are device-only, so only App Store
    // rows are seeded; otherwise `activeProducts` would change shape when the
    // read lands. (The fast path is StoreKit 2 only; see `ConfigManager`.)
    //
    // A subscription with no expiry can't be shown to be current, and the read
    // doesn't count one as active either, so it isn't restored active.
    let activeSubscriptions = customerInfo.subscriptions.filter {
      guard let expiresAt = $0.expirationDate else {
        return false
      }
      return $0.store == .appStore && $0.isActive && expiresAt > now
    }
    let activeTransactionIds = Set(activeSubscriptions.map { $0.transactionId })
    let subscriptionPurchases = customerInfo.subscriptions
      .filter { $0.store == .appStore }
      .map {
        Purchase(
          id: $0.productId,
          isActive: activeTransactionIds.contains($0.transactionId),
          purchaseDate: $0.purchaseDate
        )
      }
    // Same rule as the read: with no expiry, only a non-consumable stays active.
    let nonSubscriptionPurchases = customerInfo.nonSubscriptions
      .filter { $0.store == .appStore }
      .map {
        Purchase(
          id: $0.productId,
          isActive: !$0.isRevoked && !$0.isConsumable,
          purchaseDate: $0.purchaseDate
        )
      }
    let purchases = Set(subscriptionPurchases + nonSubscriptionPurchases)
    await manager.seedPurchases(purchases)

    // Config knows every product and the entitlements it unlocks. The saved
    // customer info knows which of those were active, and carries fields like
    // willRenew that audience filters read, so its copy wins where both have one.
    // Lapsed rows are deactivated before the grants go in, so a saved row that
    // shares an id with a grant can't drag the grant down with it: once it's
    // inactive, `mergePrioritized` prefers the active grant.
    let saved = customerInfo.entitlements.map { entitlement in
      let lapsed = entitlement.isActive && hasExpired(entitlement.expiresAt, at: now)
      return lapsed ? deactivated(entitlement) : entitlement
    }
    // Every load merges the developer's grants back in, so the restore does too.
    // Otherwise a grant made since the last launch, which the saved copy
    // predates, would look inactive until the read lands. Merged the way the
    // load merges them, so the richer copy wins field by field.
    let merged = Entitlement.mergePrioritized(saved + Array(grantedEntitlements))
    let savedById = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
    let entitlementsByProductId = ConfigLogic.extractEntitlements(from: config)
      .mapValues { Set($0.map { savedById[$0.id] ?? $0 }) }
    Superwall.shared.entitlements.setEntitlementsFromConfig(entitlementsByProductId)

    activeSubscriptionGroupIds = Set(activeSubscriptions.compactMap { $0.subscriptionGroupId })

    // The customer info and status were restored from disk exactly as saved, so
    // a row that lapsed since the last launch still reads active through them.
    // Publish both lapse-corrected, the way the read does when it lands: the
    // status via the same delegate call, from the seeded purchases and the
    // corrected entitlement map. Audience filters read these while config is
    // already published, so they see the same state as `entitlementsByProductId`.
    //
    // With an external purchase controller the status is the controller's and
    // the customer info is rebuilt from it, so the saved copy is left alone:
    // replacing it here would drop an entitlement the controller set since
    // launch, and the delegate call is a no-op on that path anyway.
    if factory.makeHasExternalPurchaseController() {
      return
    }
    // Rows follow the seeded purchases: an App Store subscription with no
    // expiry can't be shown to be current, so it's inactive here even though
    // its entitlement, which follows the entitlement rule above, keeps its
    // saved state.
    let subscriptions = customerInfo.subscriptions.map { subscription -> SubscriptionTransaction in
      let stillActive: Bool
      if subscription.store == .appStore {
        stillActive = activeTransactionIds.contains(subscription.transactionId)
      } else {
        stillActive = subscription.isActive && !hasExpired(subscription.expirationDate, at: now)
      }
      return subscription.isActive && !stillActive ? deactivated(subscription) : subscription
    }
    let restoredCustomerInfo = CustomerInfo(
      subscriptions: subscriptions,
      nonSubscriptions: customerInfo.nonSubscriptions,
      entitlements: merged.sorted { $0.id < $1.id },
      isPlaceholder: customerInfo.isPlaceholder
    )
    await MainActor.run {
      Superwall.shared.customerInfo = restoredCustomerInfo
    }
    await receiptDelegate?.syncSubscriptionStatus(purchases: purchases)
  }

  /// A nil expiry never lapses: lifetime purchases and web entitlements without one.
  private func hasExpired(_ expiresAt: Date?, at now: Date) -> Bool {
    guard let expiresAt = expiresAt else {
      return false
    }
    return expiresAt <= now
  }

  private func deactivated(_ subscription: SubscriptionTransaction) -> SubscriptionTransaction {
    return SubscriptionTransaction(
      transactionId: subscription.transactionId,
      productId: subscription.productId,
      purchaseDate: subscription.purchaseDate,
      willRenew: subscription.willRenew,
      isRevoked: subscription.isRevoked,
      isInGracePeriod: subscription.isInGracePeriod,
      isInBillingRetryPeriod: subscription.isInBillingRetryPeriod,
      isActive: false,
      expirationDate: subscription.expirationDate,
      offerType: subscription.offerType,
      subscriptionGroupId: subscription.subscriptionGroupId,
      store: subscription.store
    )
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
