//
//  PaywallBillingPlanTests.swift
//  SuperwallKitTests
//

@testable import SuperwallKit
import Testing
import Foundation

// swiftlint:disable all

struct PaywallBillingPlanTests {
  @Test
  func appStoreProductIdentifiers_dedupesAcrossBillingPlans() {
    let monthly = Product(
      name: "annual_monthly",
      type: .appStore(AppStoreProduct(id: "com.app.annual", billingPlanType: .monthly)),
      id: "com.app.annual:MONTHLY",
      entitlements: []
    )
    let upfront = Product(
      name: "annual_upfront",
      type: .appStore(AppStoreProduct(id: "com.app.annual", billingPlanType: .upFront)),
      id: "com.app.annual:UP_FRONT",
      entitlements: []
    )
    let other = Product(
      name: "monthly",
      type: .appStore(AppStoreProduct(id: "com.app.monthly", billingPlanType: nil)),
      id: "com.app.monthly",
      entitlements: []
    )

    var paywall = Paywall.stub()
    paywall.products = [monthly, upfront, other]

    // Composite IDs (slot-level): all three distinct.
    #expect(paywall.appStoreProductIds.sorted() == [
      "com.app.annual:MONTHLY",
      "com.app.annual:UP_FRONT",
      "com.app.monthly"
    ])

    // Apple product identifiers (for StoreKit fetch): deduped.
    #expect(paywall.appStoreProductIdentifiers.sorted() == [
      "com.app.annual",
      "com.app.monthly"
    ])
  }

  @Test
  func productIdsWithIntroOffers_isDeduped() {
    var paywall = Paywall.stub()
    paywall.productVariables = [
      ProductVariable(name: "a", attributes: JSON([String: Any]()), id: "com.app.annual", hasIntroOffer: true),
      ProductVariable(name: "b", attributes: JSON([String: Any]()), id: "com.app.annual", hasIntroOffer: true),
      ProductVariable(name: "c", attributes: JSON([String: Any]()), id: "com.app.weekly", hasIntroOffer: true),
      ProductVariable(name: "d", attributes: JSON([String: Any]()), id: "com.app.no_trial", hasIntroOffer: false)
    ]

    let ids = paywall.productIdsWithIntroOffers.sorted()
    #expect(ids == ["com.app.annual", "com.app.weekly"])
  }
}
