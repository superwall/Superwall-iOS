//
//  PurchasePresentationBuilderTests.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("PurchasePresentationBuilder")
struct PurchasePresentationBuilderTests {
  let now = Date(timeIntervalSince1970: 1_700_000_000)
  var builder: PurchasePresentationBuilder {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return PurchasePresentationBuilder(now: { now }, strings: .english, dateFormatter: formatter)
  }
  func sub(
    _ id: String,
    active: Bool = true,
    willRenew: Bool = true,
    expires: TimeInterval? = 86_400,
    revoked: Bool = false,
    grace: Bool = false,
    retry: Bool = false,
    offer: LatestSubscription.OfferType? = nil,
    store: ProductStore = .appStore,
    group: String? = "g1"
  ) -> SubscriptionTransaction {
    SubscriptionTransaction(
      transactionId: "t_\(id)",
      productId: id,
      purchaseDate: now.addingTimeInterval(-86_400),
      willRenew: willRenew,
      isRevoked: revoked,
      isInGracePeriod: grace,
      isInBillingRetryPeriod: retry,
      isActive: active,
      expirationDate: expires.map { now.addingTimeInterval($0) },
      offerType: offer,
      subscriptionGroupId: group,
      store: store
    )
  }
  func info(
    subs: [SubscriptionTransaction] = [],
    nonSubs: [NonSubscriptionTransaction] = [],
    entitlements: [Entitlement] = []
  ) -> CustomerInfo {
    CustomerInfo(subscriptions: subs, nonSubscriptions: nonSubs, entitlements: entitlements)
  }
  let monthly = ProductDisplayInfo(
    productId: "monthly",
    title: "Monthly",
    localizedPrice: "$9.99",
    price: 9.99,
    localizedPeriod: "month",
    subscriptionGroupId: "g1",
    isAutoRenewable: true
  )

  @Test("active renewing subscription: Active badge, renews line with price")
  func activeRenewing() {
    let rows = builder.build(customerInfo: info(subs: [sub("monthly")]), products: ["monthly": monthly])
    #expect(rows.count == 1)
    #expect(rows[0].title == "Monthly")
    #expect(rows[0].badge == .active)
    #expect(rows[0].priceLine == "$9.99 / month")
    #expect(rows[0].statusLine == "Renews on 2023-11-15 for $9.99")
  }

  @Test("badge priority: lifetime > revoked > expired > billingIssue > cancelled > freeTrial > active")
  func badgePriority() {
    let products = ["monthly": monthly]
    func badge(_ subscription: SubscriptionTransaction) -> PurchaseBadge {
      builder.build(customerInfo: info(subs: [subscription]), products: products)[0].badge
    }
    #expect(badge(sub("monthly", revoked: true)) == .revoked)
    #expect(badge(sub("monthly", active: false, expires: -10)) == .expired)
    #expect(badge(sub("monthly", grace: true)) == .billingIssue)
    #expect(badge(sub("monthly", retry: true)) == .billingIssue)
    #expect(badge(sub("monthly", willRenew: false)) == .cancelled)
    #expect(badge(sub("monthly", offer: .trial)) == .freeTrial)
    let lifetime = Entitlement(id: "pro", isActive: true, store: .appStore, isLifetime: true)
    let lifetimeRows = builder.build(customerInfo: info(entitlements: [lifetime]), products: [:])
    #expect(lifetimeRows[0].badge == .lifetime)
  }

  @Test("status lines")
  func statusLines() {
    let products = ["monthly": monthly]
    func status(_ subscription: SubscriptionTransaction) -> String {
      builder.build(customerInfo: info(subs: [subscription]), products: products)[0].statusLine
    }
    #expect(status(sub("monthly", willRenew: false)) == "Expires on 2023-11-15")
    #expect(status(sub("monthly", active: false, expires: -86_400)) == "Expired on 2023-11-13")
    #expect(status(sub("monthly", offer: .trial)) == "Free trial until 2023-11-15")
    #expect(status(sub("monthly", grace: true)) == "Billing issue – update your payment method to keep access")
  }

  @Test("missing product falls back to product id and omits price")
  func missingProduct() {
    let rows = builder.build(customerInfo: info(subs: [sub("monthly")]), products: [:])
    #expect(rows[0].title == "monthly")
    #expect(rows[0].priceLine == nil)
    #expect(rows[0].statusLine == "Renews on 2023-11-15")
  }

  @Test("sorting: active by expiration ascending, inactive last, then non-subs, then entitlement-only")
  func sorting() {
    let subs = [sub("late", expires: 200), sub("dead", active: false, expires: -5), sub("soon", expires: 100)]
    let nonSub = NonSubscriptionTransaction(
      transactionId: "n",
      productId: "coins",
      purchaseDate: now,
      isConsumable: true,
      isRevoked: false,
      store: .appStore
    )
    let ent = Entitlement(id: "granted", isActive: true, store: .superwall)
    let rows = builder.build(customerInfo: info(subs: subs, nonSubs: [nonSub], entitlements: [ent]), products: [:])
    // Non-subscription rows are keyed by transaction id ("n"), not product id, so repeat
    // consumable purchases of the same product each get their own row.
    #expect(rows.map(\.id) == ["soon", "late", "dead", "n", "entitlement:granted"])
  }

  @Test("store labels")
  func storeLabels() {
    func storeLabelKey(_ subscription: SubscriptionTransaction) -> String? {
      builder.build(customerInfo: info(subs: [subscription]), products: [:])[0].storeLabelKey
    }
    #expect(storeLabelKey(sub("w", store: .stripe)) == "customer_center_store_web")
    #expect(storeLabelKey(sub("p", store: .playStore)) == "customer_center_store_google_play")
    #expect(storeLabelKey(sub("s", store: .superwall)) == "customer_center_store_superwall")
    #expect(storeLabelKey(sub("a")) == nil)
  }

  @Test("entitlement-only rows are built only for entitlements with no matching transaction")
  func entitlementOnly() {
    let ent = Entitlement(id: "pro", isActive: true, productIds: ["monthly"], store: .appStore)
    let rows = builder.build(customerInfo: info(subs: [sub("monthly")], entitlements: [ent]), products: [:])
    #expect(rows.count == 1)
  }

  @Test("inactive subscription with no expiration date falls back to Expired status line")
  func expiredWithNoDateFallsBackToExpired() {
    let subscription = sub("monthly", active: false, expires: nil)
    let rows = builder.build(customerInfo: info(subs: [subscription]), products: [:])
    #expect(rows[0].badge == .expired)
    #expect(rows[0].statusLine == "Expired")
  }

  @Test("sorting: active subscription with nil expiration date sorts after a dated active subscription")
  func nilExpirationSortsAfterDatedActiveSubscription() {
    let subs = [sub("no-date", expires: nil), sub("dated", expires: 200)]
    let rows = builder.build(customerInfo: info(subs: subs), products: [:])
    #expect(rows.map(\.id) == ["dated", "no-date"])
  }

  // MARK: - Renewal collapsing

  @Test("renewals of one product collapse to a single row, preferring the active transaction")
  func renewalsCollapseToActiveRow() {
    // Three StoreKit transactions of the same subscription: two lapsed renewal periods plus the
    // current one. `CustomerInfo.subscriptions` reports all three; the user has one subscription.
    let subs = [
      sub("monthly", active: false, expires: -172_800),
      sub("monthly", active: false, expires: -86_400),
      sub("monthly", active: true, expires: 86_400)
    ]
    let rows = builder.build(customerInfo: info(subs: subs), products: ["monthly": monthly])
    #expect(rows.count == 1)
    #expect(rows[0].id == "monthly")
    #expect(rows[0].badge == .active)
    #expect(rows[0].isActive)
    #expect(rows[0].subscription?.expirationDate == now.addingTimeInterval(86_400))
  }

  @Test("all-expired renewals collapse to a single row carrying the latest expiration")
  func expiredRenewalsCollapseToLatestExpiration() {
    let subs = [
      sub("monthly", active: false, expires: -172_800),
      sub("monthly", active: false, expires: -3_600),
      sub("monthly", active: false, expires: -86_400)
    ]
    let rows = builder.build(customerInfo: info(subs: subs), products: ["monthly": monthly])
    #expect(rows.count == 1)
    #expect(rows[0].badge == .expired)
    #expect(rows[0].subscription?.expirationDate == now.addingTimeInterval(-3_600))
  }

  @Test("repeat purchases of the same consumable stay as separate rows with distinct ids")
  func repeatConsumablePurchasesKeepDistinctRows() {
    func coins(_ transactionId: String, purchasedAgo: TimeInterval) -> NonSubscriptionTransaction {
      NonSubscriptionTransaction(
        transactionId: transactionId,
        productId: "coins",
        purchaseDate: now.addingTimeInterval(-purchasedAgo),
        isConsumable: true,
        isRevoked: false,
        store: .appStore
      )
    }
    let rows = builder.build(
      customerInfo: info(nonSubs: [coins("n1", purchasedAgo: 172_800), coins("n2", purchasedAgo: 3_600)]),
      products: [:]
    )
    #expect(rows.count == 2)
    #expect(rows.map(\.id) == ["n1", "n2"])
    #expect(Set(rows.map(\.id)).count == 2)
    #expect(rows.allSatisfy { $0.productId == "coins" })
  }
}
