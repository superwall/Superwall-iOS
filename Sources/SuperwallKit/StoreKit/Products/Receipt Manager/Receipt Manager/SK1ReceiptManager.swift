//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/09/2024.
//

import Foundation

final class SK1ReceiptManager: ReceiptManagerType {
  private let receiptData: () -> Data?
  var purchasedSubscriptionGroupIds: Set<String>?
  var purchases: Set<Purchase> = []

  // Unused in SK1:
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType?
  var latestSubscriptionWillAutoRenew: Bool?
  var latestSubscriptionState: LatestSubscription.State?
  var appTransactionId: String?
  let transactionReceipts: [TransactionReceipt] = []
  let appTransactionId: String? = nil

  init(
    receiptData: @escaping () -> Data? = ReceiptLogic.getReceiptData
  ) {
    self.receiptData = receiptData
  }

  func loadIntroOfferEligibility(forProducts storeProducts: Set<StoreProduct>) async {
    var purchasedSubscriptionGroupIds: Set<String> = []
    for storeProduct in storeProducts {
      if let subscriptionGroupIdentifier = storeProduct.subscriptionGroupIdentifier {
        purchasedSubscriptionGroupIds.insert(subscriptionGroupIdentifier)
      }
    }
    self.purchasedSubscriptionGroupIds = purchasedSubscriptionGroupIds
  }

  func loadPurchases(serverEntitlementsByProductId: [String: Set<Entitlement>]) async -> PurchaseSnapshot {
    // SK1 doesn't have detailed transaction info, so we create a minimal CustomerInfo
    // with just entitlements based on active purchases
    guard let payload = ReceiptLogic.getPayload(using: receiptData) else {
      // No receipt - return all entitlements from config as inactive
      let inactiveEntitlements = serverEntitlementsByProductId.values
        .flatMap { $0 }
        .map { serverEntitlement in
          Entitlement(
            id: serverEntitlement.id,
            type: serverEntitlement.type,
            isActive: false,
            productIds: serverEntitlement.productIds
          )
        }
        .sorted { $0.id < $1.id }

      return PurchaseSnapshot(
        purchases: [],
        customerInfo: CustomerInfo(
          subscriptions: [],
          nonSubscriptions: [],
          entitlements: inactiveEntitlements
        )
      )
    }

    purchases = Set(payload.purchases.map {
      Purchase(
        id: $0.productIdentifier,
        isActive: $0.isActive,
        purchaseDate: $0.purchaseDate
      )
    })

    // Build map of active product IDs for quick lookup
    let activeProductIds = Set(purchases.filter { $0.isActive }.map { $0.id })

    // Process all entitlements from config, enhancing them with active status
    // For SK1, we collect all product IDs per entitlement, then mark as active if ANY product is active
    var entitlementProductIds: [String: Set<String>] = [:]
    var entitlementTypes: [String: EntitlementType] = [:]

    // First pass: collect all product IDs per entitlement
    for (productId, serverEntitlements) in serverEntitlementsByProductId {
      for serverEntitlement in serverEntitlements {
        entitlementProductIds[serverEntitlement.id, default: []].insert(productId)
        entitlementTypes[serverEntitlement.id] = serverEntitlement.type
      }
    }

    // Second pass: create entitlements with active status
    var entitlements: [Entitlement] = []
    for (entitlementId, productIds) in entitlementProductIds {
      // Entitlement is active if ANY of its products is active
      let isActive = productIds.contains { activeProductIds.contains($0) }

      entitlements.append(
        Entitlement(
          id: entitlementId,
          type: entitlementTypes[entitlementId] ?? .serviceLevel,
          isActive: isActive,
          productIds: productIds
        )
      )
    }

    entitlements.sort { $0.id < $1.id }

    return PurchaseSnapshot(
      purchases: purchases,
      customerInfo: CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: entitlements
      )
    )
  }

  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool {
    guard storeProduct.hasFreeTrial else {
      return false
    }
    guard
      let purchasedSubscriptionGroupIds = purchasedSubscriptionGroupIds,
      let subsGroupId = storeProduct.subscriptionGroupIdentifier
    else {
      return !hasPurchasedProduct(withId: storeProduct.productIdentifier)
    }

    return !purchasedSubscriptionGroupIds.contains(subsGroupId)
  }

  /// Determines whether the purchases already contain the given product ID.
  func hasPurchasedProduct(withId productId: String) -> Bool {
    return purchases.first { $0.id == productId } != nil
  }
}
