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
  /// The entitlements the purchase unlocks.
  var entitlements: Set<Entitlement> = []
  /// Whether the product's name and price are still loading from the Superwall catalogue.
  var isAwaitingCatalogue = false

  /// What the delegate and SwiftUI callbacks are told about this purchase.
  var publicPurchase: CustomerCenterPurchase {
    switch kind {
    case .subscription(let sub):
      return CustomerCenterPurchase(productId: productId, store: store, entitlements: entitlements, subscription: sub)
    case .nonSubscription(let purchase):
      return CustomerCenterPurchase(
        productId: productId,
        store: store,
        entitlements: entitlements,
        nonSubscription: purchase
      )
    case .entitlementOnly:
      return CustomerCenterPurchase(productId: productId, store: store, entitlements: entitlements)
    }
  }

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

/// The purchase a Customer Center action applies to.
@objc(SWKCustomerCenterPurchase)
@objcMembers
public final class CustomerCenterPurchase: NSObject {
  /// The product purchased. `nil` for an entitlement with no product behind it, such as a
  /// manually granted one.
  public let productId: String?
  /// Where the purchase was made.
  public let store: ProductStore
  /// The entitlements the purchase unlocks, including any it no longer grants: for a purchase
  /// with a transaction behind it these are every entitlement the product has ever unlocked, so
  /// check ``Entitlement/isActive`` before treating one as current.
  public let entitlements: Set<Entitlement>
  /// The subscription, when the purchase is one.
  public let subscription: SubscriptionTransaction?
  /// The one-time purchase, when the purchase is one.
  public let nonSubscription: NonSubscriptionTransaction?

  init(
    productId: String?,
    store: ProductStore,
    entitlements: Set<Entitlement>,
    subscription: SubscriptionTransaction? = nil,
    nonSubscription: NonSubscriptionTransaction? = nil
  ) {
    self.productId = productId
    self.store = store
    self.entitlements = entitlements
    self.subscription = subscription
    self.nonSubscription = nonSubscription
  }
}
