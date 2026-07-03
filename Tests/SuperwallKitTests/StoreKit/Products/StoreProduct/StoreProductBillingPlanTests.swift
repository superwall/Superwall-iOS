//
//  StoreProductBillingPlanTests.swift
//  SuperwallKitTests
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Regression tests for the `StoreProductType.isBillingPlanAvailable` default.
///
/// The protocol default previously returned `true`, so SK1 / custom products —
/// which have no billing plan — reported `isBillingPlanAvailable == true`,
/// contradicting `SK2StoreProduct` (which returns `false` when no plan is
/// configured) and the documented `StoreProduct` contract. That made paywall
/// templates gating billing-plan copy behave differently in test mode (SK1)
/// versus production (SK2). The default is now `false`.
@Suite("StoreProduct billing plan availability")
struct StoreProductBillingPlanTests {
  @Test("SK1 products report no billing plan available")
  func sk1ProductReportsNoBillingPlanAvailable() {
    let product = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: "com.app.annual"),
      entitlements: []
    )

    #expect(product.isBillingPlanAvailable == false)
    #expect(product.billingPlanType == nil)
    #expect(product.attributes["isBillingPlanAvailable"] == "false")
  }
}
