//
//  CustomProductTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 2026-03-12.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Tests for custom product model decoding, StoreProduct integration,
/// custom transaction creation, and trial eligibility.
struct CustomProductTests {
  private func makeCustomStoreProduct(
    id: String = "custom_prod_1",
    trialPeriodDays: Int = 7,
    entitlements: Set<Entitlement> = [Entitlement(id: "premium", type: .serviceLevel, isActive: false)]
  ) -> StoreProduct {
    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: id,
      platform: .custom,
      price: SuperwallProductPrice(amount: 999, currency: "USD"),
      subscription: SuperwallProductSubscription(
        period: .month,
        periodCount: 1,
        trialPeriodDays: trialPeriodDays
      ),
      entitlements: [],
      storefront: "USA"
    )
    let testProduct = TestStoreProduct(
      superwallProduct: superwallProduct,
      entitlements: entitlements
    )
    return StoreProduct(customProduct: testProduct)
  }

  // MARK: - CustomStoreProduct Decoding

  @Test
  func customStoreProduct_decodesFromJSON() throws {
    let json = """
    {
      "productIdentifier": "custom_prod_123",
      "store": "CUSTOM"
    }
    """
    let data = json.data(using: .utf8)!
    let product = try JSONDecoder().decode(CustomStoreProduct.self, from: data)
    #expect(product.id == "custom_prod_123")
  }

  @Test
  func customStoreProduct_failsDecodingNonCustomStore() {
    let json = """
    {
      "productIdentifier": "some_prod",
      "store": "APP_STORE"
    }
    """
    let data = json.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(CustomStoreProduct.self, from: data)
    }
  }

  @Test
  func customStoreProduct_encodesRoundTrip() throws {
    let product = CustomStoreProduct(id: "custom_prod_456")
    let data = try JSONEncoder().encode(product)
    let decoded = try JSONDecoder().decode(CustomStoreProduct.self, from: data)
    #expect(decoded.id == "custom_prod_456")
    #expect(decoded == product)
  }

  @Test
  func customStoreProduct_equality() {
    let product1 = CustomStoreProduct(id: "prod_1")
    let product2 = CustomStoreProduct(id: "prod_1")
    let product3 = CustomStoreProduct(id: "prod_2")

    #expect(product1 == product2)
    #expect(product1 != product3)
  }

  @Test
  func customStoreProduct_hashEquality() {
    let product1 = CustomStoreProduct(id: "prod_1")
    let product2 = CustomStoreProduct(id: "prod_1")

    #expect(product1.hash == product2.hash)
  }

  // MARK: - Product with .custom type

  @Test
  func product_customType_decodesFromJSON() throws {
    let json = """
    {
      "referenceName": "primary",
      "storeProduct": {
        "productIdentifier": "custom_prod_abc",
        "store": "CUSTOM"
      },
      "swCompositeProductId": "custom_prod_abc",
      "entitlements": [
        {"identifier": "premium", "type": "SERVICE_LEVEL"}
      ]
    }
    """
    let data = json.data(using: .utf8)!
    let product = try JSONDecoder().decode(Product.self, from: data)

    #expect(product.name == "primary")
    #expect(product.id == "custom_prod_abc")

    if case .custom(let customProduct) = product.type {
      #expect(customProduct.id == "custom_prod_abc")
    } else {
      Issue.record("Expected .custom type but got \(product.type)")
    }

    #expect(product.entitlements.count == 1)
    #expect(product.entitlements.first?.id == "premium")
  }

  @Test
  func product_customType_encodesRoundTrip() throws {
    let product = Product(
      name: "primary",
      type: .custom(.init(id: "custom_abc")),
      id: "custom_abc",
      entitlements: [Entitlement(id: "premium", type: .serviceLevel, isActive: false)]
    )

    let data = try JSONEncoder().encode(product)
    let decoded = try JSONDecoder().decode(Product.self, from: data)

    #expect(decoded.name == "primary")
    #expect(decoded.id == "custom_abc")
    if case .custom = decoded.type {} else {
      Issue.record("Expected .custom type after round trip")
    }
  }

  // MARK: - ProductStore .custom

  @Test
  func productStore_customCase() throws {
    let json = "\"CUSTOM\""
    let data = json.data(using: .utf8)!
    let store = try JSONDecoder().decode(ProductStore.self, from: data)
    #expect(store == .custom)
    #expect(store.description == "CUSTOM")
  }

  // MARK: - PaywallLogic.getCustomProducts

  @Test
  func getCustomProducts_filtersCustomOnly() {
    let customProduct = Product(
      name: "custom1",
      type: .custom(.init(id: "custom_1")),
      id: "custom_1",
      entitlements: []
    )
    let appStoreProduct = Product(
      name: "primary",
      type: .appStore(.init(id: "app_1")),
      id: "app_1",
      entitlements: []
    )
    let stripeProduct = Product(
      name: "stripe1",
      type: .stripe(.init(id: "stripe_1", trialDays: nil)),
      id: "stripe_1",
      entitlements: []
    )

    let result = PaywallLogic.getCustomProducts(from: [customProduct, appStoreProduct, stripeProduct])

    #expect(result.count == 1)
    #expect(result.first?.id == "custom_1")
  }

  @Test
  func getCustomProducts_emptyWhenNoCustom() {
    let appStoreProduct = Product(
      name: "primary",
      type: .appStore(.init(id: "app_1")),
      id: "app_1",
      entitlements: []
    )

    let result = PaywallLogic.getCustomProducts(from: [appStoreProduct])
    #expect(result.isEmpty)
  }

  // MARK: - StoreProduct custom init

  @Test
  func storeProduct_customInit_setsIsCustomProduct() {
    let storeProduct = makeCustomStoreProduct(entitlements: [])

    #expect(storeProduct.isCustomProduct)
    #expect(storeProduct.customTransactionId == nil)
    #expect(storeProduct.productIdentifier == "custom_prod_1")
  }

  @Test
  func storeProduct_testInit_doesNotSetCustomFlag() {
    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: "test_prod_1",
      platform: .ios,
      price: SuperwallProductPrice(amount: 999, currency: "USD"),
      subscription: nil,
      entitlements: [],
      storefront: "USA"
    )
    let testProduct = TestStoreProduct(
      superwallProduct: superwallProduct,
      entitlements: []
    )
    let storeProduct = StoreProduct(testProduct: testProduct)

    #expect(!storeProduct.isCustomProduct)
  }

  // MARK: - TestStoreProduct attribute computation

  @Test
  func testStoreProduct_computesPrice() {
    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: "custom_1",
      platform: .custom,
      price: SuperwallProductPrice(amount: 1999, currency: "USD"),
      subscription: SuperwallProductSubscription(
        period: .month,
        periodCount: 1,
        trialPeriodDays: nil
      ),
      entitlements: [],
      storefront: "USA"
    )
    let testProduct = TestStoreProduct(
      superwallProduct: superwallProduct,
      entitlements: []
    )

    #expect(testProduct.price == Decimal(1999) / 100)
    #expect(testProduct.productIdentifier == "custom_1")
    #expect(!testProduct.hasFreeTrial)
  }

  @Test
  func testStoreProduct_computesTrialInfo() {
    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: "custom_2",
      platform: .custom,
      price: SuperwallProductPrice(amount: 499, currency: "EUR"),
      subscription: SuperwallProductSubscription(
        period: .year,
        periodCount: 1,
        trialPeriodDays: 14
      ),
      entitlements: [],
      storefront: "USA"
    )
    let testProduct = TestStoreProduct(
      superwallProduct: superwallProduct,
      entitlements: []
    )

    #expect(testProduct.hasFreeTrial)
    #expect(testProduct.trialPeriodDays == 14)
    #expect(testProduct.trialPeriodWeeks == 2)
    #expect(testProduct.period == "year")
    #expect(testProduct.periodDays == 365)
    #expect(testProduct.currencyCode == "EUR")
  }

  @Test
  func testStoreProduct_noSubscription() {
    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: "custom_otp",
      platform: .custom,
      price: SuperwallProductPrice(amount: 2499, currency: "USD"),
      subscription: nil,
      entitlements: [],
      storefront: "USA"
    )
    let testProduct = TestStoreProduct(
      superwallProduct: superwallProduct,
      entitlements: []
    )

    #expect(!testProduct.hasFreeTrial)
    #expect(testProduct.trialPeriodDays == 0)
    #expect(testProduct.period == "")
    #expect(testProduct.periodDays == 0)
    #expect(testProduct.subscriptionPeriod == nil)
  }

  // MARK: - CustomStoreTransaction

  @Test
  func customStoreTransaction_properties() {
    let txnId = "custom-txn-123"
    let productId = "custom_prod_1"
    let purchaseDate = Date()

    let transaction = CustomStoreTransaction(
      customTransactionId: txnId,
      productIdentifier: productId,
      purchaseDate: purchaseDate
    )

    #expect(transaction.originalTransactionIdentifier == txnId)
    #expect(transaction.storeTransactionId == txnId)
    #expect(transaction.state == .purchased)
    #expect(transaction.transactionDate == purchaseDate)
    #expect(transaction.originalTransactionDate == purchaseDate)
    #expect(transaction.payment.productIdentifier == productId)
    #expect(transaction.payment.quantity == 1)
    #expect(transaction.payment.discountIdentifier == nil)

    // SK2-specific properties should be nil
    #expect(transaction.webOrderLineItemID == nil)
    #expect(transaction.appBundleId == nil)
    #expect(transaction.subscriptionGroupId == nil)
    #expect(transaction.isUpgraded == nil)
    #expect(transaction.expirationDate == nil)
    #expect(transaction.offerId == nil)
    #expect(transaction.revocationDate == nil)
    #expect(transaction.appAccountToken == nil)
  }

  @Test
  func prepareToPurchase_customProduct_marksFreeTrialAvailableWhenUserHasNoPriorEntitlement() async {
    let dependencyContainer = DependencyContainer()
    let product = makeCustomStoreProduct()
    let superwall = Superwall.shared
    let originalCustomerInfo = superwall.customerInfo
    defer {
      superwall.customerInfo = originalCustomerInfo
    }

    superwall.customerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: []
    )

    await dependencyContainer.transactionManager.prepareToPurchase(
      product: product,
      purchaseSource: .purchaseFunc(product)
    )

    let coordinator = dependencyContainer.makePurchasingCoordinator()
    #expect(await coordinator.isFreeTrialAvailable)
  }

  @Test
  func prepareToPurchase_customProduct_doesNotMarkFreeTrialAvailableWhenUserHadEntitlement() async {
    let dependencyContainer = DependencyContainer()
    let product = makeCustomStoreProduct()
    let superwall = Superwall.shared
    let originalCustomerInfo = superwall.customerInfo
    defer {
      superwall.customerInfo = originalCustomerInfo
    }

    superwall.customerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [
        Entitlement(
          id: "premium",
          type: .serviceLevel,
          isActive: false,
          latestProductId: "old_product",
          store: .custom
        )
      ]
    )

    await dependencyContainer.transactionManager.prepareToPurchase(
      product: product,
      purchaseSource: .purchaseFunc(product)
    )

    let coordinator = dependencyContainer.makePurchasingCoordinator()
    #expect(!(await coordinator.isFreeTrialAvailable))
  }

  // MARK: - Custom Trial Eligibility

  /// Replicates `hasEverHadEntitlement` logic from `AddPaywallProducts`.
  private static func hasEverHadEntitlement(
    forProductEntitlements productEntitlements: Set<Entitlement>,
    userEntitlements: [Entitlement]
  ) -> Bool {
    let productEntitlementIds = Set(productEntitlements.map { $0.id })
    if productEntitlementIds.isEmpty {
      return false
    }
    let userEntitlementIds = Set(
      userEntitlements
        .filter { $0.latestProductId != nil || $0.store == .superwall || $0.isActive }
        .map { $0.id }
    )
    return !productEntitlementIds.isDisjoint(with: userEntitlementIds)
  }

  /// Simulates `checkCustomTrialEligibility` from `AddPaywallProducts`.
  private func checkCustomTrialEligibility(
    productItems: [SuperwallKit.Product],
    productsById: [String: StoreProduct],
    introOfferEligibility: IntroOfferEligibility,
    userEntitlements: [Entitlement]
  ) -> Bool {
    if introOfferEligibility == .ineligible {
      return false
    }

    for productItem in productItems {
      if case .custom = productItem.type {
        guard let storeProduct = productsById[productItem.id] else {
          continue
        }
        if storeProduct.hasFreeTrial {
          if productItem.entitlements.isEmpty {
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
      }
    }
    return false
  }

  /// Helper to create a custom product item.
  private func makeCustomProductItem(
    id: String = "custom_prod_1",
    name: String = "primary",
    entitlements: Set<Entitlement> = []
  ) -> SuperwallKit.Product {
    return SuperwallKit.Product(
      name: name,
      type: .custom(.init(id: id)),
      id: id,
      entitlements: entitlements
    )
  }

  /// Helper to create a StoreProduct backed by a TestStoreProduct with trial.
  private func makeCustomStoreProductForTrialEligibility(
    id: String = "custom_prod_1",
    trialDays: Int? = nil
  ) -> StoreProduct {
    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: id,
      platform: .custom,
      price: SuperwallProductPrice(amount: 999, currency: "USD"),
      subscription: SuperwallProductSubscription(
        period: .month,
        periodCount: 1,
        trialPeriodDays: trialDays
      ),
      entitlements: [],
      storefront: "USA"
    )
    let testProduct = TestStoreProduct(
      superwallProduct: superwallProduct,
      entitlements: []
    )
    return StoreProduct(customProduct: testProduct)
  }

  @Test
  func customTrialEligibility_hasTrialNoEntitlementHistory_eligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeCustomProductItem(
      entitlements: [premiumEntitlement]
    )
    let storeProduct = makeCustomStoreProductForTrialEligibility(trialDays: 7)

    let result = checkCustomTrialEligibility(
      productItems: [productItem],
      productsById: [productItem.id: storeProduct],
      introOfferEligibility: .eligible,
      userEntitlements: []
    )

    #expect(result)
  }

  @Test
  func customTrialEligibility_hasTrialWithEntitlementHistory_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeCustomProductItem(
      entitlements: [premiumEntitlement]
    )
    let storeProduct = makeCustomStoreProductForTrialEligibility(trialDays: 7)

    let userEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      latestProductId: "custom_prod_1",
      store: .custom
    )

    let result = checkCustomTrialEligibility(
      productItems: [productItem],
      productsById: [productItem.id: storeProduct],
      introOfferEligibility: .eligible,
      userEntitlements: [userEntitlement]
    )

    #expect(!result)
  }

  @Test
  func customTrialEligibility_noTrialDays_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeCustomProductItem(
      entitlements: [premiumEntitlement]
    )
    let storeProduct = makeCustomStoreProductForTrialEligibility(trialDays: nil)

    let result = checkCustomTrialEligibility(
      productItems: [productItem],
      productsById: [productItem.id: storeProduct],
      introOfferEligibility: .eligible,
      userEntitlements: []
    )

    #expect(!result)
  }

  @Test
  func customTrialEligibility_ineligibleMode_notEligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeCustomProductItem(
      entitlements: [premiumEntitlement]
    )
    let storeProduct = makeCustomStoreProductForTrialEligibility(trialDays: 7)

    let result = checkCustomTrialEligibility(
      productItems: [productItem],
      productsById: [productItem.id: storeProduct],
      introOfferEligibility: .ineligible,
      userEntitlements: []
    )

    #expect(!result)
  }

  @Test
  func customTrialEligibility_noEntitlementsConfigured_skipsProduct() {
    let productItem = makeCustomProductItem(entitlements: [])
    let storeProduct = makeCustomStoreProductForTrialEligibility(trialDays: 7)

    let result = checkCustomTrialEligibility(
      productItems: [productItem],
      productsById: [productItem.id: storeProduct],
      introOfferEligibility: .eligible,
      userEntitlements: []
    )

    #expect(!result)
  }

  @Test
  func customTrialEligibility_notInProductsById_skipsProduct() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeCustomProductItem(
      entitlements: [premiumEntitlement]
    )

    // No matching product in productsById
    let result = checkCustomTrialEligibility(
      productItems: [productItem],
      productsById: [:],
      introOfferEligibility: .eligible,
      userEntitlements: []
    )

    #expect(!result)
  }

  @Test
  func customTrialEligibility_configPlaceholderEntitlement_eligible() {
    let premiumEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false
    )
    let productItem = makeCustomProductItem(
      entitlements: [premiumEntitlement]
    )
    let storeProduct = makeCustomStoreProductForTrialEligibility(trialDays: 7)

    // Config-only placeholder: no latestProductId, no store, not active
    let placeholderEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: false,
      latestProductId: nil,
      store: nil
    )

    let result = checkCustomTrialEligibility(
      productItems: [productItem],
      productsById: [productItem.id: storeProduct],
      introOfferEligibility: .eligible,
      userEntitlements: [placeholderEntitlement]
    )

    #expect(result)
  }

  // MARK: - getProductVariables with custom products

  @Test
  func getProductVariables_includesCustomProduct() {
    let productId = "custom_prod_1"
    let products = [Product(
      name: "primary",
      type: .custom(.init(id: productId)),
      id: productId,
      entitlements: []
    )]

    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: productId,
      platform: .custom,
      price: SuperwallProductPrice(amount: 999, currency: "USD"),
      subscription: SuperwallProductSubscription(
        period: .month,
        periodCount: 1,
        trialPeriodDays: nil
      ),
      entitlements: [],
      storefront: "USA"
    )
    let testProduct = TestStoreProduct(
      superwallProduct: superwallProduct,
      entitlements: []
    )
    let storeProduct = StoreProduct(customProduct: testProduct)
    let productsById = [productId: storeProduct]

    let response = PaywallLogic.getProductVariables(
      productItems: products,
      productsById: productsById
    )

    #expect(response.productVariables.count == 1)
    #expect(response.productVariables.first?.name == "primary")
    #expect(response.productVariables.first?.id == productId)
  }

  @Test
  func getProductVariables_customProductNotInCache_skipped() {
    let productId = "custom_prod_1"
    let products = [Product(
      name: "primary",
      type: .custom(.init(id: productId)),
      id: productId,
      entitlements: []
    )]

    let response = PaywallLogic.getProductVariables(
      productItems: products,
      productsById: [:]
    )

    #expect(response.productVariables.isEmpty)
  }
}
