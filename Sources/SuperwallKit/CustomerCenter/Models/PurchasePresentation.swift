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
  /// The product's display name, or `nil` when neither StoreKit nor the catalogue supplied one.
  /// Never the identifier standing in for one: a card without a name shows no name.
  var title: String?
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
  /// What the card is headed with: the product's display name, else the entitlement it unlocks,
  /// else nothing. The purchase is always shown; only this label is allowed to be absent.
  var title: String?
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

  /// Whether the row opens a detail screen — which is where a purchase's own actions live.
  ///
  /// A subscription does. So does an entitlement-only purchase: a web subscription arrives as a
  /// bare entitlement whenever the backend sends no matching transaction, and that customer still
  /// has a management page to reach. Splitting on `subscription != nil` alone stranded them —
  /// the only row that could carry the management link had nowhere to open. A one-off purchase
  /// has no action of its own, so it stays a plain card.
  var opensDetail: Bool {
    if case .nonSubscription = kind { return false }
    return true
  }
}
