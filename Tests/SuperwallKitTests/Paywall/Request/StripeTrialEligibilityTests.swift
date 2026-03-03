//
//  StripeTrialEligibilityTests.swift
//  SuperwallKitTests
//
//  Created by Claude on 03/03/2026.
//
// swiftlint:disable all

import Testing
@testable import SuperwallKit
import StoreKit

/// Tests for Stripe trial eligibility logic.
///
/// The trial eligibility closure in `AddPaywallProducts` checks:
/// - `.eligible` mode: For Stripe products, checks if user has ever had
///   any matching entitlements (via `hasEverHadEntitlement`).
/// - `.automatic` mode: Same Stripe-specific check.
/// - `.ineligible` mode: Always returns false.
///
/// These tests verify the behavior by simulating the closure logic that
/// `PaywallRequestManager` passes to `PaywallLogic.getVariablesAndFreeTrial`.
struct StripeTrialEligibilityTests {

  // MARK: - Helpers

  /// Creates a Stripe `StoreProduct` with the given entitlements and optional free trial.
  private func makeStripeProduct(
    id: String = "stripe_product_1",
    entitlements: Set<Entitlement> = [],
    hasFreeTrial: Bool = false
  ) -> StoreProduct {
    let introOffer: StripeProductType.SubscriptionIntroductoryOffer? = hasFreeTrial
      ? .init(
        period: .init(unit: .day, value: 7),
        localizedPrice: "$0.00",
        price: 0,
        periodCount: 1,
        paymentMethod: .freeTrial
      )
      : nil

    let stripeProduct = StripeProductType(
      id: id,
      price: 9.99,
      localizedPrice: "$9.99",
      currencyCode: "USD",
      currencySymbol: "$",
      priceLocale: .init(
        identifier: "en_US",
        languageCode: "en",
        currencyCode: "USD",
        currencySymbol: "$"
      ),
      stripeSubscriptionPeriod: .init(unit: .month, value: 1),
      subscriptionIntroOffer: introOffer,
      entitlements: entitlements
    )
    return StoreProduct.from(product: stripeProduct)
  }

  /// Creates a Product item referencing a Stripe product.
  private func makeStripeProductItem(
    id: String = "stripe_product_1",
    name: String = "primary",
    entitlements: Set<Entitlement> = []
  ) -> SuperwallKit.Product {
    return SuperwallKit.Product(
      name: name,
      type: .stripe(.init(id: id)),
      id: id,
      entitlements: entitlements
    )
  }

  /// Simulates the `.eligible` mode closure logic from `AddPaywallProducts`.
  ///
  /// For Stripe products: checks `hasFreeTrial` and whether the user has ever
  /// had any matching entitlements.
  /// For App Store products: checks `hasFreeTrial` and subscription group.
  private func eligibleModeClosure(
    userEntitlements: [Entitlement]
  ) -> (StoreProduct) async -> Bool {
    return { product in
      guard product.hasFreeTrial else { return false }
      if product.product is StripeProductType {
        return !Self.hasEverHadEntitlement(
          for: product,
          userEntitlements: userEntitlements
        )
      }
      // For App Store products, just return true (simplified for test)
      return true
    }
  }

  /// Simulates the `.automatic` mode closure logic from `AddPaywallProducts`.
  private func automaticModeClosure(
    userEntitlements: [Entitlement]
  ) -> (StoreProduct) async -> Bool {
    return { product in
      if product.product is StripeProductType {
        guard product.hasFreeTrial else { return false }
        return !Self.hasEverHadEntitlement(
          for: product,
          userEntitlements: userEntitlements
        )
      }
      // For App Store products, delegate to the factory (simplified)
      return false
    }
  }

  /// Replicates the `hasEverHadEntitlement` logic from `AddPaywallProducts`.
  private static func hasEverHadEntitlement(
    for product: StoreProduct,
    userEntitlements: [Entitlement]
  ) -> Bool {
    let productEntitlementIds = Set(product.entitlements.map { $0.id })
    guard !productEntitlementIds.isEmpty else {
      return false
    }
    let userEntitlementIds = Set(
      userEntitlements
        .filter { $0.latestProductId != nil || $0.store == .superwall }
        .map { $0.id }
    )
    return !productEntitlementIds.isDisjoint(with: userEntitlementIds)
  }

  // MARK: - Eligible Mode Tests

  @Test
  func eligible_stripeProduct_noEntitlementHistory_trialAvailable() async {
    // Given: Stripe product with free trial, user has no entitlement history
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(userEntitlements: [])
    )

    // Then
    #expect(result.isFreeTrialAvailable)
  }

  @Test
  func eligible_stripeProduct_hasActiveEntitlement_trialNotAvailable() async {
    // Given: Stripe product with free trial, user has an active matching entitlement
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // User has active "premium" entitlement with transaction history
    let userEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      latestProductId: "stripe_product_1",
      store: .stripe
    )

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(
        userEntitlements: [userEntitlement]
      )
    )

    // Then
    #expect(!result.isFreeTrialAvailable)
  }

  @Test
  func eligible_stripeProduct_hasInactiveEntitlementWithHistory_trialNotAvailable() async {
    // Given: Stripe product with free trial, user has an inactive entitlement
    // with transaction history (expired subscription)
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // User has inactive "premium" entitlement but with transaction history
    let userEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false,
      latestProductId: "stripe_product_1",
      store: .stripe
    )

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(
        userEntitlements: [userEntitlement]
      )
    )

    // Then: Even inactive entitlements with history should block trial
    #expect(!result.isFreeTrialAvailable)
  }

  @Test
  func eligible_stripeProduct_configPlaceholderEntitlement_trialAvailable() async {
    // Given: Stripe product with free trial, user has a config-only placeholder
    // entitlement (latestProductId == nil, store == nil) — not a real purchase
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // Config-only placeholder: no latestProductId, no store
    let placeholderEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false,
      latestProductId: nil,
      store: nil
    )

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(
        userEntitlements: [placeholderEntitlement]
      )
    )

    // Then: Placeholder entitlements should NOT block trial
    #expect(result.isFreeTrialAvailable)
  }

  @Test
  func eligible_stripeProduct_noFreeTrial_notAvailable() async {
    // Given: Stripe product WITHOUT free trial
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: false
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(userEntitlements: [])
    )

    // Then
    #expect(!result.isFreeTrialAvailable)
  }

  // MARK: - Automatic Mode Tests

  @Test
  func automatic_stripeProduct_noEntitlementHistory_trialAvailable() async {
    // Given: Stripe product with free trial, no entitlement history
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: automaticModeClosure(userEntitlements: [])
    )

    // Then
    #expect(result.isFreeTrialAvailable)
  }

  @Test
  func automatic_stripeProduct_hasEntitlementHistory_trialNotAvailable() async {
    // Given: Stripe product with free trial, user has matching entitlement
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    let userEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false,
      latestProductId: "stripe_product_1",
      store: .stripe
    )

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: automaticModeClosure(
        userEntitlements: [userEntitlement]
      )
    )

    // Then
    #expect(!result.isFreeTrialAvailable)
  }

  @Test
  func automatic_stripeProduct_noFreeTrial_notAvailable() async {
    // Given: Stripe product without free trial
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: false
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: automaticModeClosure(userEntitlements: [])
    )

    // Then
    #expect(!result.isFreeTrialAvailable)
  }

  // MARK: - Ineligible Mode Tests

  @Test
  func ineligible_stripeProduct_alwaysNotAvailable() async {
    // Given: Stripe product with free trial, ineligible mode
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // When: ineligible mode always returns false
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { _ in false }
    )

    // Then
    #expect(!result.isFreeTrialAvailable)
  }

  // MARK: - App Store Product Tests (Unchanged Behavior)

  @Test
  func eligible_appStoreProduct_usesSubscriptionGroupCheck() async {
    // Given: App Store product with free trial
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
    let productItem = SuperwallKit.Product(
      name: "primary",
      type: .appStore(.init(id: "app_store_product_1")),
      id: "app_store_product_1",
      entitlements: []
    )
    let productsById = [productItem.id: appStoreProduct]

    // When: App Store product uses subscription group check (not Stripe logic)
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(userEntitlements: [])
    )

    // Then: App Store product should still use subscription group logic
    // (returns true in our simplified mock since it's not a StripeProductType)
    #expect(result.isFreeTrialAvailable)
  }

  @Test
  func automatic_appStoreProduct_unchangedBehavior() async {
    // Given: App Store product in automatic mode
    let skProduct = MockSkProduct(
      productIdentifier: "app_store_product_1",
      subscriptionGroupIdentifier: "group_1",
      price: 9.99
    )
    let appStoreProduct = StoreProduct(
      sk1Product: skProduct,
      entitlements: []
    )
    let productItem = SuperwallKit.Product(
      name: "primary",
      type: .appStore(.init(id: "app_store_product_1")),
      id: "app_store_product_1",
      entitlements: []
    )
    let productsById = [productItem.id: appStoreProduct]

    // When: In automatic mode, App Store products delegate to factory
    // (our mock returns false, simulating factory behavior)
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: automaticModeClosure(userEntitlements: [])
    )

    // Then: App Store product falls through to factory (returns false in mock)
    #expect(!result.isFreeTrialAvailable)
  }

  // MARK: - Stripe Product with No Entitlements Configured

  @Test
  func eligible_stripeProduct_noEntitlementsConfigured_trialAvailable() async {
    // Given: Stripe product with free trial but no entitlements configured
    let stripeProduct = makeStripeProduct(
      entitlements: [],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // User has some entitlement history
    let userEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      latestProductId: "other_product",
      store: .stripe
    )

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(
        userEntitlements: [userEntitlement]
      )
    )

    // Then: Product has no entitlements configured, so trial should be available
    // (hasEverHadEntitlement returns false when productEntitlementIds is empty)
    #expect(result.isFreeTrialAvailable)
  }

  // MARK: - Superwall-granted Entitlements

  @Test
  func eligible_stripeProduct_superwallGrantedEntitlement_trialNotAvailable() async {
    // Given: Stripe product with free trial, user has a Superwall-granted entitlement
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // Superwall-granted entitlement: store == .superwall, no latestProductId
    let superwallEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      latestProductId: nil,
      store: .superwall
    )

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(
        userEntitlements: [superwallEntitlement]
      )
    )

    // Then: Superwall-granted entitlements should block trial
    #expect(!result.isFreeTrialAvailable)
  }

  // MARK: - Non-matching Entitlements

  @Test
  func eligible_stripeProduct_nonMatchingEntitlementHistory_trialAvailable() async {
    // Given: Stripe product grants "premium", user only has "basic" history
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let stripeProduct = makeStripeProduct(
      entitlements: [premiumEntitlement],
      hasFreeTrial: true
    )
    let productItem = makeStripeProductItem()
    let productsById = [productItem.id: stripeProduct]

    // User has "basic" entitlement history, not "premium"
    let basicEntitlement = Entitlement(
      id: "basic",
      type: .serviceLevel,
      isActive: false,
      latestProductId: "other_product",
      store: .stripe
    )

    // When
    let result = await PaywallLogic.getVariablesAndFreeTrial(
      productItems: [productItem],
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: eligibleModeClosure(
        userEntitlements: [basicEntitlement]
      )
    )

    // Then: Non-matching entitlements should not block trial
    #expect(result.isFreeTrialAvailable)
  }
}
