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
      id: "com.app.annual",
      entitlements: []
    )
    let upfront = Product(
      name: "annual_upfront",
      type: .appStore(AppStoreProduct(id: "com.app.annual", billingPlanType: .upFront)),
      id: "com.app.annual",
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

    // Public IDs stay bare, and the cache keys keep the slots apart.
    #expect(paywall.appStoreProductIds.sorted() == [
      "com.app.annual",
      "com.app.annual",
      "com.app.monthly"
    ])
    #expect(paywall.products.map(\.cacheKey).sorted() == [
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

  private func paywallSellingBothPlans() -> Paywall {
    var paywall = Paywall.stub()
    paywall.products = [
      Product(
        name: "productLeft",
        type: .appStore(AppStoreProduct(id: "com.app.annual", billingPlanType: .upFront)),
        id: "com.app.annual",
        entitlements: []
      ),
      Product(
        name: "productLeftInstalments",
        type: .appStore(AppStoreProduct(id: "com.app.annual", billingPlanType: .monthly)),
        id: "com.app.annual",
        entitlements: []
      ),
      Product(
        name: "productRight",
        type: .appStore(AppStoreProduct(id: "com.app.monthly", billingPlanType: nil)),
        id: "com.app.monthly",
        entitlements: []
      )
    ]
    return paywall
  }

  @Test
  func cacheKey_usesTheSlotNamedByThePurchaseMessage() {
    let paywall = paywallSellingBothPlans()

    #expect(
      paywall.cacheKey(forProductId: "com.app.annual", referenceName: "productLeft")
        == "com.app.annual:UP_FRONT"
    )
    #expect(
      paywall.cacheKey(forProductId: "com.app.annual", referenceName: "productLeftInstalments")
        == "com.app.annual:MONTHLY"
    )
  }

  @Test
  func cacheKey_fallsBackToTheFirstSlotWithTheId() {
    let paywall = paywallSellingBothPlans()

    #expect(
      paywall.cacheKey(forProductId: "com.app.annual", referenceName: nil)
        == "com.app.annual:UP_FRONT"
    )
    #expect(
      paywall.cacheKey(forProductId: "com.app.annual", referenceName: "someOtherSlot")
        == "com.app.annual:UP_FRONT"
    )
    #expect(paywall.cacheKey(forProductId: "notOnPaywall", referenceName: nil) == "notOnPaywall")
  }

  @Test
  func referenceName_isOnlyReportedWhenTheIdCantIdentifyTheSlot() {
    let paywall = paywallSellingBothPlans()

    #expect(paywall.referenceName(forCacheKey: "com.app.annual:MONTHLY") == "productLeftInstalments")
    #expect(paywall.referenceName(forCacheKey: "com.app.annual:UP_FRONT") == "productLeft")
    #expect(paywall.referenceName(forCacheKey: "com.app.monthly") == nil)
    #expect(paywall.referenceName(forCacheKey: "notOnPaywall") == nil)
  }

  @Test
  func referenceName_isNilWhenSlotsShareAPlan() {
    var paywall = Paywall.stub()
    paywall.products = ["a", "b"].map {
      Product(
        name: $0,
        type: .appStore(AppStoreProduct(id: "com.app.annual", billingPlanType: .monthly)),
        id: "com.app.annual",
        entitlements: []
      )
    }

    #expect(paywall.referenceName(forCacheKey: "com.app.annual:MONTHLY") == nil)
  }

  @Test
  func decodedProduct_keepsItsBareIdWithABillingPlan() throws {
    let json = """
    {
      "reference_name": "productLeft",
      "sw_composite_product_id": "com.app.annual",
      "entitlements": [],
      "store_product": {
        "store": "APP_STORE",
        "product_identifier": "com.app.annual",
        "billing_plan_type": "UP_FRONT"
      }
    }
    """
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    let product = try decoder.decode(Product.self, from: Data(json.utf8))

    #expect(product.id == "com.app.annual")
    #expect(product.cacheKey == "com.app.annual:UP_FRONT")
  }
}
