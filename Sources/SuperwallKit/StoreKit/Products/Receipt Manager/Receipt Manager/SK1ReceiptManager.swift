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

  // Unused for now:
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType?
  var latestSubscriptionWillAutoRenew: Bool?
  var latestSubscriptionState: LatestSubscription.State?

  /// This is unused in SK1
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
    // TODO: SK1 Stuff
    guard let payload = ReceiptLogic.getPayload(using: receiptData) else {
      return PurchaseSnapshot(
        purchases: [],
        entitlementsByProductId: serverEntitlementsByProductId,
        nonSubscriptions: [],
        subscriptions: []
      )
    }
    purchases = Set(payload.purchases.map {
      Purchase(
        id: $0.productIdentifier,
        isActive: $0.isActive,
        purchaseDate: $0.purchaseDate
      )
    })
    return PurchaseSnapshot(
      purchases: purchases,
      entitlementsByProductId: serverEntitlementsByProductId,
      nonSubscriptions: [],
      subscriptions: []
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
