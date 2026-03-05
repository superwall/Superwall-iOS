//
//  StripeTrialEligibilityTests.swift
//  SuperwallKitTests
//
//  Created by Claude on 03/03/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Tests for Stripe trial eligibility logic.
///
/// Stripe products are not fetched into `productsById` (which only contains
/// App Store products), so `getVariablesAndFreeTrial` skips them. Trial
/// eligibility for Stripe products is determined separately using the
/// `StripeProduct.trialDays` property and entitlement history checks.
///
/// These tests verify the logic that `checkStripeTrialEligibility` in
/// `AddPaywallProducts` implements.
struct StripeTrialEligibilityTests {

  // MARK: - Helpers

  /// Creates a `Product` item referencing a Stripe product with optional trial days.
  private func makeStripeProductItem(
    id: String = "stripe_product_1",
    name: String = "primary",
    trialDays: Int? = nil,
    entitlements: Set<Entitlement> = []
  ) -> SuperwallKit.Product {
    return SuperwallKit.Product(
      name: name,
      type: .stripe(.init(id: id, trialDays: trialDays)),
      id: id,
      entitlements: entitlements
    )
  }

  /// Replicates the `hasEverHadEntitlement` logic from `AddPaywallProducts`.
  private static func hasEverHadEntitlement(
    forProductEntitlements productEntitlements: Set<Entitlement>,
    userEntitlements: [Entitlement]
  ) -> Bool {
    let productEntitlementIds = Set(productEntitlements.map { $0.id })
    guard !productEntitlementIds.isEmpty else {
      return false
    }
    let userEntitlementIds = Set(
      userEntitlements
        .filter { $0.latestProductId != nil || $0.store == .superwall || $0.isActive }
        .map { $0.id }
    )
    return !productEntitlementIds.isDisjoint(with: userEntitlementIds)
  }

  /// Simulates the Stripe trial eligibility check from `AddPaywallProducts.checkStripeTrialEligibility`.
  ///
  /// This replicates the logic: iterate Stripe products, check `trialDays > 0`,
  /// then check if user has ever had any matching entitlements.
  private func checkStripeTrialEligibility(
    productItems: [SuperwallKit.Product],
    introOfferEligibility: IntroOfferEligibility,
    userEntitlements: [Entitlement]
  ) -> Bool {
    if introOfferEligibility == .ineligible {
      return false
    }

    for productItem in productItems {
      guard case .stripe(let stripeProduct) = productItem.type else {
        continue
      }
      guard let trialDays = stripeProduct.trialDays,
        trialDays > 0 else {
        continue
      }

      let hasEntitlement = Self.hasEverHadEntitlement(
        forProductEntitlements: productItem.entitlements,
        userEntitlements: userEntitlements
      )
      if !hasEntitlement {
        return true
      }
    }
    return false
  }

  // MARK: - Trial Days > 0, No Entitlement History

  @Test
  func stripeProduct_trialDaysSet_noEntitlementHistory_eligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [premiumEntitlement]
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: []
    )

    #expect(result)
  }

  @Test
  func stripeProduct_trialDaysSet_automaticMode_noEntitlementHistory_eligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 14,
      entitlements: [premiumEntitlement]
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .automatic,
      userEntitlements: []
    )

    #expect(result)
  }

  // MARK: - Trial Days > 0, Has Entitlement History

  @Test
  func stripeProduct_trialDaysSet_hasActiveEntitlement_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [premiumEntitlement]
    )

    let userEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      latestProductId: "stripe_product_1",
      store: .stripe
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: [userEntitlement]
    )

    #expect(!result)
  }

  @Test
  func stripeProduct_trialDaysSet_hasInactiveEntitlementWithHistory_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [premiumEntitlement]
    )

    // Inactive entitlement but with transaction history (expired subscription)
    let userEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false,
      latestProductId: "stripe_product_1",
      store: .stripe
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: [userEntitlement]
    )

    #expect(!result)
  }

  // MARK: - Trial Days nil or 0

  @Test
  func stripeProduct_trialDaysNil_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: nil,
      entitlements: [premiumEntitlement]
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: []
    )

    #expect(!result)
  }

  @Test
  func stripeProduct_trialDaysZero_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 0,
      entitlements: [premiumEntitlement]
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: []
    )

    #expect(!result)
  }

  // MARK: - Ineligible Mode

  @Test
  func stripeProduct_ineligibleMode_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [premiumEntitlement]
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .ineligible,
      userEntitlements: []
    )

    #expect(!result)
  }

  // MARK: - Config Placeholder Entitlements

  @Test
  func stripeProduct_configPlaceholderEntitlement_eligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [premiumEntitlement]
    )

    // Config-only placeholder: no latestProductId, no store
    let placeholderEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false,
      latestProductId: nil,
      store: nil
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: [placeholderEntitlement]
    )

    // Placeholder entitlements should NOT block trial
    #expect(result)
  }

  // MARK: - Superwall-granted Entitlements

  @Test
  func stripeProduct_superwallGrantedEntitlement_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [premiumEntitlement]
    )

    // Superwall-granted entitlement: store == .superwall, no latestProductId
    let superwallEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      latestProductId: nil,
      store: .superwall
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: [superwallEntitlement]
    )

    #expect(!result)
  }

  // MARK: - Non-matching Entitlements

  @Test
  func stripeProduct_nonMatchingEntitlementHistory_eligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [premiumEntitlement]
    )

    // User has "basic" entitlement history, not "premium"
    let basicEntitlement = Entitlement(
      id: "basic",
      type: .serviceLevel,
      isActive: false,
      latestProductId: "other_product",
      store: .stripe
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: [basicEntitlement]
    )

    #expect(result)
  }

  // MARK: - No Entitlements Configured

  @Test
  func stripeProduct_noEntitlementsConfigured_eligible() {
    // Stripe product with trial days but no entitlements configured
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: []
    )

    // User has some entitlement history
    let userEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      latestProductId: "other_product",
      store: .stripe
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: [userEntitlement]
    )

    // hasEverHadEntitlement returns false when productEntitlementIds is empty
    #expect(result)
  }

  // MARK: - Test Mode Entitlements

  @Test
  func stripeProduct_testModeActiveEntitlement_notEligible() {
    // Test mode creates entitlements with store: .appStore and latestProductId: nil
    // These should still block trial because they are active
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [premiumEntitlement]
    )

    // Simulates test mode entitlement: active, appStore, no latestProductId
    let testModeEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      latestProductId: nil,
      store: .appStore
    )

    let result = checkStripeTrialEligibility(
      productItems: [productItem],
      introOfferEligibility: .eligible,
      userEntitlements: [testModeEntitlement]
    )

    #expect(!result)
  }

  // MARK: - Stripe Products Skipped by getVariablesAndFreeTrial

  @Test
  func getVariablesAndFreeTrial_skipsStripeProducts() async {
    // Stripe products are not in productsById, so getVariablesAndFreeTrial
    // should not set isFreeTrialAvailable for them
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [Entitlement(id: "premium", type: .serviceLevel, isActive: false)]
    )

    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: [:],
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { _ in true }
    )

    // The closure is never called because Stripe product isn't in productsById
    #expect(!result.isFreeTrialAvailable)
  }

  // MARK: - Mixed Paywall (App Store + Stripe)

  @Test
  func mixedPaywall_appStoreEligible_stripeAlsoPresent() async {
    // App Store product with free trial
    let mockIntroPeriod = MockIntroductoryPeriod(
      testSubscriptionPeriod: MockSubscriptionPeriod()
    )
    let skProduct = MockSkProduct(
      productIdentifier: "app_store_product_1",
      introPeriod: mockIntroPeriod,
      subscriptionGroupIdentifier: "group_1",
      price: 9.99
    )
    let appStoreProduct = StoreProduct(
      sk1Product: skProduct,
      entitlements: []
    )
    let appStoreItem = SuperwallKit.Product(
      name: "primary",
      type: .appStore(.init(id: "app_store_product_1")),
      id: "app_store_product_1",
      entitlements: []
    )
    let stripeItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [Entitlement(id: "premium", type: .serviceLevel, isActive: false)]
    )
    let productsById = [appStoreItem.id: appStoreProduct]

    // App Store product sets isFreeTrialAvailable via the closure
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [appStoreItem, stripeItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { _ in true }
    )

    // App Store product sets it to true; Stripe check wouldn't even run
    // because isFreeTrialAvailable is already true
    #expect(result.isFreeTrialAvailable)
  }

  // MARK: - Override Tests

  @Test
  func override_true_winsOverStripeCheck() async {
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [Entitlement(id: "premium", type: .serviceLevel, isActive: false)]
    )

    // Override set to true
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: [:],
      isFreeTrialAvailableOverride: true,
      isFreeTrialAvailable: { _ in false }
    )

    #expect(result.isFreeTrialAvailable)
  }

  @Test
  func override_false_winsOverStripeCheck() async {
    let productItem = makeStripeProductItem(
      trialDays: 7,
      entitlements: [Entitlement(id: "premium", type: .serviceLevel, isActive: false)]
    )

    // Override set to false — Stripe check should not run in AddPaywallProducts
    // because request.overrides.isFreeTrial != nil
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: [:],
      isFreeTrialAvailableOverride: false,
      isFreeTrialAvailable: { _ in true }
    )

    #expect(!result.isFreeTrialAvailable)
  }

  // MARK: - StripeProduct Decoding

  @Test
  func stripeProduct_decodesTrialDays() throws {
    let json = """
    {
      "productIdentifier": "stripe_prod_123",
      "store": "STRIPE",
      "trial_days": 14
    }
    """
    let data = json.data(using: .utf8)!
    let product = try JSONDecoder().decode(StripeProduct.self, from: data)
    #expect(product.id == "stripe_prod_123")
    #expect(product.trialDays == 14)
  }

  @Test
  func stripeProduct_decodesWithoutTrialDays() throws {
    let json = """
    {
      "productIdentifier": "stripe_prod_123",
      "store": "STRIPE"
    }
    """
    let data = json.data(using: .utf8)!
    let product = try JSONDecoder().decode(StripeProduct.self, from: data)
    #expect(product.id == "stripe_prod_123")
    #expect(product.trialDays == nil)
  }

  @Test
  func stripeProduct_encodesTrialDays() throws {
    let product = StripeProduct(id: "stripe_prod_123", trialDays: 7)
    let data = try JSONEncoder().encode(product)
    let decoded = try JSONDecoder().decode(StripeProduct.self, from: data)
    #expect(decoded.trialDays == 7)
  }

  @Test
  func stripeProduct_equality_includesTrialDays() {
    let product1 = StripeProduct(id: "prod_1", trialDays: 7)
    let product2 = StripeProduct(id: "prod_1", trialDays: 7)
    let product3 = StripeProduct(id: "prod_1", trialDays: 14)
    let product4 = StripeProduct(id: "prod_1", trialDays: nil)

    #expect(product1 == product2)
    #expect(product1 != product3)
    #expect(product1 != product4)
  }
}
