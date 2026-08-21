//
//  PurchasePresentation.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

/// Display-oriented product info, decoupled from `StoreProduct` for testability.
struct ProductDisplayInfo: Equatable {
  var productId: String
  var title: String
  var localizedPrice: String?
  var price: Decimal?
  var localizedPeriod: String?
  var subscriptionGroupId: String?
  var isAutoRenewable: Bool?
}

enum PurchaseBadge: Equatable {
  case lifetime, revoked, expired, billingIssue, cancelled, freeTrial, active
}

enum PurchaseKind: Equatable {
  case subscription(SubscriptionTransaction)
  case nonSubscription(NonSubscriptionTransaction)
  case entitlementOnly(Entitlement)
}

struct PurchasePresentation: Identifiable, Equatable {
  var id: String
  var kind: PurchaseKind
  var productId: String?
  var title: String
  var priceLine: String?
  var statusLine: String
  var badge: PurchaseBadge
  var store: ProductStore
  var storeLabelKey: String?
  var isActive: Bool
  var expirationDate: Date?
  var purchaseDate: Date?

  var subscription: SubscriptionTransaction? {
    if case .subscription(let sub) = kind { return sub }
    return nil
  }
}
