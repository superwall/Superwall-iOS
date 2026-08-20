//
//  PurchasePresentationBuilder.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

/// Builds display-ready `PurchasePresentation` rows from raw `CustomerInfo`.
struct PurchasePresentationBuilder {
  var now: () -> Date = Date.init
  var strings: CustomerCenterStrings
  var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()

  func build(customerInfo: CustomerInfo, products: [String: ProductDisplayInfo]) -> [PurchasePresentation] {
    let subs = subscriptionPresentations(customerInfo.subscriptions, products: products)
    let nonSubs = nonSubscriptionPresentations(customerInfo.nonSubscriptions, products: products)
    let knownProductIds = Set(
      customerInfo.subscriptions.map(\.productId) + customerInfo.nonSubscriptions.map(\.productId)
    )
    let entitlementOnly = customerInfo.entitlements
      .filter { $0.isActive && $0.productIds.isDisjoint(with: knownProductIds) }
      .map(entitlementPresentation)
    return subs + nonSubs + entitlementOnly
  }

  func subscriptionPresentations(
    _ subscriptions: [SubscriptionTransaction],
    products: [String: ProductDisplayInfo]
  ) -> [PurchasePresentation] {
    let sorted = subscriptions.sorted { lhs, rhs in
      if lhs.isActive != rhs.isActive { return lhs.isActive }
      switch (lhs.expirationDate, rhs.expirationDate) {
      case let (lhsDate?, rhsDate?): return lhsDate < rhsDate
      case (nil, _?): return false
      case (_?, nil): return true
      case (nil, nil): return lhs.purchaseDate < rhs.purchaseDate
      }
    }
    return sorted.map { presentation(for: $0, product: products[$0.productId]) }
  }

  func nonSubscriptionPresentations(
    _ purchases: [NonSubscriptionTransaction],
    products: [String: ProductDisplayInfo]
  ) -> [PurchasePresentation] {
    purchases.sorted { $0.purchaseDate < $1.purchaseDate }.map { purchase in
      let product = products[purchase.productId]
      return PurchasePresentation(
        id: purchase.productId,
        kind: .nonSubscription(purchase),
        productId: purchase.productId,
        title: product?.title ?? purchase.productId,
        priceLine: product?.localizedPrice,
        statusLine: purchase.isRevoked
          ? strings.string("customer_center_revoked")
          : strings.string("customer_center_purchased_on", dateFormatter.string(from: purchase.purchaseDate)),
        badge: purchase.isRevoked ? .revoked : .active,
        store: purchase.store,
        storeLabelKey: storeLabelKey(purchase.store),
        isActive: !purchase.isRevoked,
        expirationDate: nil,
        purchaseDate: purchase.purchaseDate
      )
    }
  }

  private func presentation(for sub: SubscriptionTransaction, product: ProductDisplayInfo?) -> PurchasePresentation {
    let badge = badge(for: sub)
    let price = product?.localizedPrice
    let date = sub.expirationDate.map { dateFormatter.string(from: $0) }
    let status: String
    switch badge {
    case .revoked: status = strings.string("customer_center_revoked")
    case .expired:
      status = date.map { strings.string("customer_center_expired_on", $0) }
        ?? strings.string("customer_center_revoked")
    case .billingIssue: status = strings.string("customer_center_billing_issue")
    case .cancelled: status = date.map { strings.string("customer_center_expires_on", $0) } ?? ""
    case .freeTrial: status = date.map { strings.string("customer_center_free_trial_until", $0) } ?? ""
    case .lifetime: status = strings.string("customer_center_lifetime")
    case .active:
      if let date, let price {
        status = strings.string("customer_center_renews_on_for", date, price)
      } else if let date {
        status = strings.string("customer_center_renews_on", date)
      } else {
        status = ""
      }
    }
    var priceLine: String?
    if let price {
      if let period = product?.localizedPeriod {
        priceLine = strings.string("customer_center_price_per_period", price, period)
      } else {
        priceLine = price
      }
    }
    return PurchasePresentation(
      id: sub.productId,
      kind: .subscription(sub),
      productId: sub.productId,
      title: product?.title ?? sub.productId,
      priceLine: priceLine,
      statusLine: status,
      badge: badge,
      store: sub.store,
      storeLabelKey: storeLabelKey(sub.store),
      isActive: sub.isActive,
      expirationDate: sub.expirationDate,
      purchaseDate: sub.purchaseDate
    )
  }

  private func entitlementPresentation(_ entitlement: Entitlement) -> PurchasePresentation {
    let isLifetime = entitlement.isLifetime == true
    let date = entitlement.expiresAt.map { dateFormatter.string(from: $0) }
    let status: String
    if isLifetime {
      status = strings.string("customer_center_lifetime")
    } else if let date {
      status = strings.string("customer_center_expires_on", date)
    } else {
      status = strings.string("customer_center_active_via_superwall")
    }
    return PurchasePresentation(
      id: "entitlement:\(entitlement.id)",
      kind: .entitlementOnly(entitlement),
      productId: entitlement.latestProductId,
      title: entitlement.id,
      priceLine: nil,
      statusLine: status,
      badge: isLifetime ? .lifetime : .active,
      store: entitlement.store ?? .superwall,
      storeLabelKey: storeLabelKey(entitlement.store ?? .superwall),
      isActive: entitlement.isActive,
      expirationDate: entitlement.expiresAt,
      purchaseDate: entitlement.startsAt
    )
  }

  func badge(for sub: SubscriptionTransaction) -> PurchaseBadge {
    if sub.isRevoked { return .revoked }
    if !sub.isActive { return .expired }
    if sub.isInGracePeriod || sub.isInBillingRetryPeriod { return .billingIssue }
    if !sub.willRenew { return .cancelled }
    if sub.offerType == .trial { return .freeTrial }
    return .active
  }

  func storeLabelKey(_ store: ProductStore) -> String? {
    switch store {
    case .appStore: return nil
    case .stripe, .paddle: return "customer_center_store_web"
    case .playStore: return "customer_center_store_google_play"
    case .superwall: return "customer_center_store_superwall"
    case .other, .custom: return "customer_center_store_other"
    }
  }
}
