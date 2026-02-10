//
//  EntitlementProcessorTests.swift
//  SuperwallKitTests
//
//  Created by Claude on 11/09/2025.
//

import Testing
import Foundation
import StoreKit
@testable import SuperwallKit

@Suite("EntitlementProcessor Tests")
struct EntitlementProcessorTests {

  // MARK: - Mock Transaction Types

  struct MockTransaction: EntitlementTransaction {
    let productId: String
    let transactionId: String
    let purchaseDate: Date
    let originalPurchaseDate: Date
    let expirationDate: Date?
    let isRevoked: Bool
    let entitlementProductType: EntitlementTransactionType
    let willRenew: Bool
    let renewedAt: Date?
    let isInGracePeriod: Bool
    let isInBillingRetryPeriod: Bool
    let isActive: Bool
    let offerType: LatestSubscription.OfferType?
    let subscriptionGroupId: String?
  }

  // MARK: - Helper Methods

  private func createMockTransaction(
    productId: String = "test_product",
    transactionId: String = "txn_123",
    purchaseDate: Date = Date(),
    originalPurchaseDate: Date? = nil,
    expirationDate: Date? = nil,
    isRevoked: Bool = false,
    productType: EntitlementTransactionType = .consumable,
    willRenew: Bool = false,
    renewedAt: Date? = nil,
    isInGracePeriod: Bool = false,
    isInBillingRetryPeriod: Bool = false,
    isActive: Bool = false,
    offerType: LatestSubscription.OfferType? = nil,
    subscriptionGroupId: String? = nil
  ) -> MockTransaction {
    return MockTransaction(
      productId: productId,
      transactionId: transactionId,
      purchaseDate: purchaseDate,
      originalPurchaseDate: originalPurchaseDate ?? purchaseDate,
      expirationDate: expirationDate,
      isRevoked: isRevoked,
      entitlementProductType: productType,
      willRenew: willRenew,
      renewedAt: renewedAt,
      isInGracePeriod: isInGracePeriod,
      isInBillingRetryPeriod: isInBillingRetryPeriod,
      isActive: isActive,
      offerType: offerType,
      subscriptionGroupId: subscriptionGroupId
    )
  }

  private func createEntitlement(
    id: String = "test_entitlement",
    productIds: Set<String> = ["test_product"]
  ) -> Entitlement {
    return Entitlement(
      id: id,
      type: .serviceLevel,
      isActive: false,
      productIds: productIds
    )
  }
  
  // MARK: - Basic Processing Tests
  
  @Test("Process empty transactions returns empty entitlements")
  func testProcessEmptyTransactions() {
    let transactionsByEntitlement: [String: [any EntitlementTransaction]] = [:]
    let rawEntitlementsByProductId: [String: Set<Entitlement>] = [:]
    let productIdsByEntitlementId: [String: Set<String>] = [:]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    #expect(result.isEmpty)
  }
  
  @Test("Process lifetime non-consumable product")
  func testProcessLifetimeProduct() {
    let transaction = createMockTransaction(
      productId: "lifetime_product",
      isRevoked: false,
      productType: .nonConsumable,
      isActive: true
    )

    let entitlement = createEntitlement(
      id: "lifetime_entitlement",
      productIds: ["lifetime_product"]
    )

    let transactionsByEntitlement = ["lifetime_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["lifetime_product": Set([entitlement])]
    let productIdsByEntitlementId = ["lifetime_entitlement": Set(["lifetime_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["lifetime_product"]?.first
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.isLifetime == true)
    #expect(processedEntitlement?.latestProductId == "lifetime_product")
  }
  
  @Test("Process active subscription")
  func testProcessActiveSubscription() {
    let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
    let transaction = createMockTransaction(
      productId: "subscription_product",
      expirationDate: futureDate,
      productType: .autoRenewable,
      willRenew: true,
      isActive: true
    )

    let entitlement = createEntitlement(
      id: "subscription_entitlement",
      productIds: ["subscription_product"]
    )

    let transactionsByEntitlement = ["subscription_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["subscription_product": Set([entitlement])]
    let productIdsByEntitlementId = ["subscription_entitlement": Set(["subscription_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["subscription_product"]?.first
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.isLifetime == false)
    #expect(processedEntitlement?.willRenew == true)
    #expect(processedEntitlement?.expiresAt == futureDate)
  }
  
  @Test("Process expired subscription")
  func testProcessExpiredSubscription() {
    let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
    let transaction = createMockTransaction(
      productId: "expired_product",
      expirationDate: pastDate,
      productType: .autoRenewable
    )

    let entitlement = createEntitlement(
      id: "expired_entitlement",
      productIds: ["expired_product"]
    )

    let transactionsByEntitlement = ["expired_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["expired_product": Set([entitlement])]
    let productIdsByEntitlementId = ["expired_entitlement": Set(["expired_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["expired_product"]?.first
    #expect(processedEntitlement?.isActive == false)
    #expect(processedEntitlement?.expiresAt == pastDate)
  }

  // MARK: - Multiple Transaction Tests
  
  @Test("Process multiple transactions for same entitlement")
  func testProcessMultipleTransactions() {
    let baseDate = Date()
    let olderTransaction = createMockTransaction(
      productId: "product1",
      transactionId: "txn_1",
      purchaseDate: baseDate.addingTimeInterval(-1000),
      expirationDate: baseDate.addingTimeInterval(-500),
      productType: .autoRenewable,
      isActive: false
    )

    let newerTransaction = createMockTransaction(
      productId: "product1",
      transactionId: "txn_2",
      purchaseDate: baseDate,
      expirationDate: baseDate.addingTimeInterval(3600), // Active
      productType: .autoRenewable,
      willRenew: true,
      isActive: true
    )

    let entitlement = createEntitlement(
      id: "multi_entitlement",
      productIds: ["product1"]
    )

    let transactionsByEntitlement = ["multi_entitlement": [olderTransaction, newerTransaction]]
    let rawEntitlementsByProductId = ["product1": Set([entitlement])]
    let productIdsByEntitlementId = ["multi_entitlement": Set(["product1"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["product1"]?.first
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.willRenew == true)
    #expect(processedEntitlement?.latestProductId == "product1")
  }
  
  @Test("Process renewal tracking")
  func testProcessRenewalTracking() {
    let baseDate = Date()
    let originalDate = baseDate.addingTimeInterval(-86400) // 1 day ago (original purchase)
    let renewalDate = baseDate // Now (renewal)

    let transaction = createMockTransaction(
      productId: "renewal_product",
      purchaseDate: renewalDate,
      originalPurchaseDate: originalDate,
      expirationDate: baseDate.addingTimeInterval(3600),
      isRevoked: false,
      productType: .autoRenewable
    )

    let entitlement = createEntitlement(
      id: "renewal_entitlement",
      productIds: ["renewal_product"]
    )

    let transactionsByEntitlement = ["renewal_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["renewal_product": Set([entitlement])]
    let productIdsByEntitlementId = ["renewal_entitlement": Set(["renewal_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["renewal_product"]?.first
    #expect(processedEntitlement?.startsAt == originalDate)
    #expect(processedEntitlement?.renewedAt == renewalDate)
  }
  
  // MARK: - Multiple Product Tests
  
  @Test("Process entitlement with multiple lifetime products")
  func testProcessMultipleLifetimeProducts() {
    let transaction1 = createMockTransaction(
      productId: "product1",
      transactionId: "txn_1",
      productType: .nonConsumable
    )

    let transaction2 = createMockTransaction(
      productId: "product2",
      transactionId: "txn_2",
      productType: .nonConsumable
    )

    let entitlement = createEntitlement(
      id: "multi_product_entitlement",
      productIds: ["product1", "product2"]
    )

    let transactionsByEntitlement = ["multi_product_entitlement": [transaction1, transaction2]]
    let rawEntitlementsByProductId = [
      "product1": Set([entitlement]),
      "product2": Set([entitlement])
    ]
    let productIdsByEntitlementId = ["multi_product_entitlement": Set(["product1", "product2"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    #expect(result.count == 2)
    #expect(result["product1"]?.first?.isActive == true)
    #expect(result["product2"]?.first?.isActive == true)
    #expect(result["product1"]?.first?.productIds.count == 2)
    #expect(result["product2"]?.first?.productIds.count == 2)
  }
  
  // MARK: - Edge Cases
  
  @Test("Process non-consumable without expiration")
  func testProcessNonConsumableWithoutExpiration() {
    let transaction = createMockTransaction(
      productId: "non_consumable",
      expirationDate: nil,
      isRevoked: false,
      productType: .nonConsumable
    )

    let entitlement = createEntitlement(
      id: "non_consumable_entitlement",
      productIds: ["non_consumable"]
    )

    let transactionsByEntitlement = ["non_consumable_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["non_consumable": Set([entitlement])]
    let productIdsByEntitlementId = ["non_consumable_entitlement": Set(["non_consumable"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["non_consumable"]?.first
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.isLifetime == true)
    #expect(processedEntitlement?.expiresAt == nil)
    #expect(processedEntitlement?.latestProductId == "non_consumable")
  }
  
  @Test("Process consumable transaction")
  func testProcessConsumableTransaction() {
    let transaction = createMockTransaction(
      productId: "consumable",
      productType: .consumable
    )

    let entitlement = createEntitlement(
      id: "consumable_entitlement",
      productIds: ["consumable"]
    )

    let transactionsByEntitlement = ["consumable_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["consumable": Set([entitlement])]
    let productIdsByEntitlementId = ["consumable_entitlement": Set(["consumable"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["consumable"]?.first
    // Consumables without expiration dates should not be considered active
    #expect(processedEntitlement?.isActive == false)
  }

  // MARK: - Complex Scenarios

  @Test("Process mixed product types in same entitlement")
  func testProcessMixedProductTypes() {
    let lifetimeTransaction = createMockTransaction(
      productId: "lifetime_product",
      transactionId: "txn_lifetime",
      isRevoked: false,
      productType: .nonConsumable
    )

    let subscriptionTransaction = createMockTransaction(
      productId: "subscription_product",
      transactionId: "txn_subscription",
      expirationDate: Date().addingTimeInterval(-3600), // Expired
      productType: .autoRenewable
    )

    let entitlement = createEntitlement(
      id: "mixed_entitlement",
      productIds: ["lifetime_product", "subscription_product"]
    )

    let transactionsByEntitlement = ["mixed_entitlement": [lifetimeTransaction, subscriptionTransaction]]
    let rawEntitlementsByProductId = [
      "lifetime_product": Set([entitlement]),
      "subscription_product": Set([entitlement])
    ]
    let productIdsByEntitlementId = ["mixed_entitlement": Set(["lifetime_product", "subscription_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // Both products should return exactly one entitlement with the same ID
    #expect(result.count == 2)
    #expect(result["lifetime_product"]?.count == 1)
    #expect(result["subscription_product"]?.count == 1)

    let lifetimeResult = result["lifetime_product"]?.first
    let subscriptionResult = result["subscription_product"]?.first

    // Both should reference the same entitlement ID
    #expect(lifetimeResult?.id == "mixed_entitlement")
    #expect(subscriptionResult?.id == "mixed_entitlement")

    // Both products should have identical enriched entitlement data
    #expect(lifetimeResult == subscriptionResult)

    // Verify the enriched data is correct (lifetime takes precedence)
    #expect(lifetimeResult?.isActive == true)
    #expect(lifetimeResult?.isLifetime == true)
    #expect(lifetimeResult?.latestProductId == "lifetime_product")
    #expect(lifetimeResult?.productIds == Set(["lifetime_product", "subscription_product"]))
  }

  @Test("Process multiple entitlements for same product")
  func testProcessMultipleEntitlementsForSameProduct() {
    let transaction = createMockTransaction(
      productId: "shared_product",
      productType: .nonConsumable
    )

    let entitlement1 = createEntitlement(
      id: "entitlement_1",
      productIds: ["shared_product"]
    )

    let entitlement2 = createEntitlement(
      id: "entitlement_2",
      productIds: ["shared_product"]
    )

    let transactionsByEntitlement = [
      "entitlement_1": [transaction],
      "entitlement_2": [transaction]
    ]
    let rawEntitlementsByProductId = [
      "shared_product": Set([entitlement1, entitlement2])
    ]
    let productIdsByEntitlementId = [
      "entitlement_1": Set(["shared_product"]),
      "entitlement_2": Set(["shared_product"])
    ]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let entitlements = result["shared_product"]
    #expect(entitlements?.count == 2)
    #expect(entitlements?.contains { $0.id == "entitlement_1" } == true)
    #expect(entitlements?.contains { $0.id == "entitlement_2" } == true)
  }

  @Test("Process latest product ID selection with multiple renewable transactions")
  func testProcessLatestProductIdSelection() {
    let baseDate = Date()
    let olderTransaction = createMockTransaction(
      productId: "old_product",
      transactionId: "txn_old",
      purchaseDate: baseDate.addingTimeInterval(-7200), // 2 hours ago
      expirationDate: baseDate.addingTimeInterval(-3600), // Expired 1 hour ago
      productType: .autoRenewable
    )

    let newerTransaction = createMockTransaction(
      productId: "new_product",
      transactionId: "txn_new",
      purchaseDate: baseDate.addingTimeInterval(-1800), // 30 minutes ago
      expirationDate: baseDate.addingTimeInterval(3600), // Active
      productType: .autoRenewable,
      isActive: true
    )

    let entitlement = createEntitlement(
      id: "version_entitlement",
      productIds: ["old_product", "new_product"]
    )

    let transactionsByEntitlement = ["version_entitlement": [olderTransaction, newerTransaction]]
    let rawEntitlementsByProductId = [
      "old_product": Set([entitlement]),
      "new_product": Set([entitlement])
    ]
    let productIdsByEntitlementId = ["version_entitlement": Set(["old_product", "new_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["new_product"]?.first
    #expect(processedEntitlement?.latestProductId == "new_product")
    #expect(processedEntitlement?.isActive == true)
  }

  @Test("Process entitlement with no matching raw entitlements")
  func testProcessEntitlementWithNoMatchingRaw() {
    let transaction = createMockTransaction(
      productId: "orphan_product",
      productType: .nonConsumable
    )

    let transactionsByEntitlement = ["orphan_entitlement": [transaction]]
    let rawEntitlementsByProductId: [String: Set<Entitlement>] = [:] // No raw entitlements
    let productIdsByEntitlementId = ["orphan_entitlement": Set(["orphan_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // Should return empty result when no matching raw entitlements
    #expect(result.isEmpty)
  }

  @Test("Process entitlement with mismatched IDs")
  func testProcessEntitlementWithMismatchedIds() {
    let transaction = createMockTransaction(
      productId: "product_a",
      productType: .nonConsumable
    )

    let entitlement = createEntitlement(
      id: "different_entitlement", // Different ID than what's in transactions
      productIds: ["product_a"]
    )

    let transactionsByEntitlement = ["transaction_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["product_a": Set([entitlement])]
    let productIdsByEntitlementId = ["transaction_entitlement": Set(["product_a"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // Should return the entitlement even though it has no transactions (as inactive)
    // This ensures all entitlements from config are preserved
    #expect(result["product_a"]?.count == 1)
    #expect(result["product_a"]?.first?.id == "different_entitlement")
    #expect(result["product_a"]?.first?.isActive == false)
  }

  @Test("Process complex expiration date selection")
  func testProcessComplexExpirationDateSelection() {
    let baseDate = Date()

    let transactions = [
      createMockTransaction(
        productId: "product1",
        transactionId: "txn_1",
        expirationDate: baseDate.addingTimeInterval(1800), // 30 min
        isRevoked: false,
        productType: .autoRenewable
      ),
      createMockTransaction(
        productId: "product2",
        transactionId: "txn_2",
        expirationDate: baseDate.addingTimeInterval(3600), // 1 hour
        isRevoked: false,
        productType: .autoRenewable
      ),
      createMockTransaction(
        productId: "product3",
        transactionId: "txn_3",
        expirationDate: baseDate.addingTimeInterval(4000), // 66 mins (latest)
        isRevoked: true, // Revoked, should be ignored
        productType: .autoRenewable
      )
    ]

    let entitlement = createEntitlement(
      id: "complex_entitlement",
      productIds: ["product1", "product2", "product3"]
    )

    let transactionsByEntitlement = ["complex_entitlement": transactions]
    let rawEntitlementsByProductId = [
      "product1": Set([entitlement]),
      "product2": Set([entitlement]),
      "product3": Set([entitlement])
    ]
    let productIdsByEntitlementId = ["complex_entitlement": Set(["product1", "product2", "product3"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["product1"]?.first
    #expect(processedEntitlement?.expiresAt == baseDate.addingTimeInterval(3600))
    #expect(processedEntitlement?.isActive == true)
  }

  @Test("Process non-renewable subscription")
  func testProcessNonRenewableSubscription() {
    let futureDate = Date().addingTimeInterval(3600)
    let transaction = createMockTransaction(
      productId: "non_renewable_product",
      expirationDate: futureDate,
      productType: .nonRenewable,
      willRenew: false,
      isActive: true
    )

    let entitlement = createEntitlement(
      id: "non_renewable_entitlement",
      productIds: ["non_renewable_product"]
    )

    let transactionsByEntitlement = ["non_renewable_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["non_renewable_product": Set([entitlement])]
    let productIdsByEntitlementId = ["non_renewable_entitlement": Set(["non_renewable_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["non_renewable_product"]?.first
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.isLifetime == false)
    #expect(processedEntitlement?.willRenew == false)
    #expect(processedEntitlement?.expiresAt == futureDate)
  }

  @Test("Process large number of transactions")
  func testProcessLargeNumberOfTransactions() {
    let baseDate = Date()
    var transactions: [MockTransaction] = []

    // Create 100 transactions
    for i in 0..<100 {
      transactions.append(
        createMockTransaction(
          productId: "product_\(i)",
          transactionId: "txn_\(i)",
          purchaseDate: baseDate.addingTimeInterval(Double(i * 60)), // Every minute
          expirationDate: baseDate.addingTimeInterval(Double(i * 60 + 3600)), // 1 hour later
          productType: .autoRenewable,
          isActive: i > 95 // Only last few are active
        )
      )
    }

    let entitlement = createEntitlement(
      id: "bulk_entitlement",
      productIds: Set(transactions.map { $0.productId })
    )

    let transactionsByEntitlement = ["bulk_entitlement": transactions]
    var rawEntitlementsByProductId: [String: Set<Entitlement>] = [:]
    for transaction in transactions {
      rawEntitlementsByProductId[transaction.productId] = Set([entitlement])
    }
    let productIdsByEntitlementId = ["bulk_entitlement": Set(transactions.map { $0.productId })]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    #expect(result.count == 100)
    // Should find the latest active transaction
    let latestProductId = "product_99"
    let processedEntitlement = result[latestProductId]?.first
    #expect(processedEntitlement?.latestProductId == latestProductId)
    #expect(processedEntitlement?.isActive == true)
  }

  @Test("Process transactions with extreme dates")
  func testProcessTransactionsWithExtremeDates() {
    let distantPast = Date.distantPast
    let distantFuture = Date.distantFuture

    let transaction = createMockTransaction(
      productId: "extreme_product",
      purchaseDate: distantPast,
      originalPurchaseDate: distantPast,
      expirationDate: distantFuture,
      productType: .autoRenewable,
      isActive: true
    )

    let entitlement = createEntitlement(
      id: "extreme_entitlement",
      productIds: ["extreme_product"]
    )

    let transactionsByEntitlement = ["extreme_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["extreme_product": Set([entitlement])]
    let productIdsByEntitlementId = ["extreme_entitlement": Set(["extreme_product"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result["extreme_product"]?.first
    #expect(processedEntitlement?.startsAt == distantPast)
    #expect(processedEntitlement?.expiresAt == distantFuture)
    #expect(processedEntitlement?.isActive == true)
  }

  @Test("Process empty product IDs")
  func testProcessEmptyProductIds() {
    let transaction = createMockTransaction(
      productId: "",
      productType: .nonConsumable
    )

    let entitlement = createEntitlement(
      id: "empty_entitlement",
      productIds: [""]
    )

    let transactionsByEntitlement = ["empty_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["": Set([entitlement])]
    let productIdsByEntitlementId = ["empty_entitlement": Set([""])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    let processedEntitlement = result[""]?.first
    #expect(processedEntitlement != nil)
    #expect(processedEntitlement?.productIds.contains("") == true)
  }

  // MARK: - Performance Tests

  @Test("Process entitlements with many-to-many relationships")
  func testProcessManyToManyRelationships() {
    // 10 entitlements each with 5 products, 5 products each with 10 entitlements
    var transactionsByEntitlement: [String: [MockTransaction]] = [:]
    var rawEntitlementsByProductId: [String: Set<Entitlement>] = [:]
    var productIdsByEntitlementId: [String: Set<String>] = [:]

    for entitlementIndex in 0..<10 {
      let entitlementId = "entitlement_\(entitlementIndex)"
      var productIds: Set<String> = []
      var transactions: [MockTransaction] = []

      for productIndex in 0..<5 {
        let productId = "product_\(productIndex)"
        productIds.insert(productId)

        transactions.append(
          createMockTransaction(
            productId: productId,
            transactionId: "txn_\(entitlementIndex)_\(productIndex)",
            productType: .nonConsumable
          )
        )

        let entitlement = createEntitlement(
          id: entitlementId,
          productIds: productIds
        )

        rawEntitlementsByProductId[productId, default: []].insert(entitlement)
      }

      transactionsByEntitlement[entitlementId] = transactions
      productIdsByEntitlementId[entitlementId] = productIds
    }

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // Should have 5 products, each with up to 10 entitlements
    #expect(result.count == 5)
    for productId in result.keys {
      #expect(result[productId]?.count == 10)
    }
  }

  // MARK: - Transaction Processing Tests

  @Test("Process transactions into subscription and non-subscription objects")
  func testProcessTransactions() {
    let transactions = [
      createMockTransaction(
        productId: "consumable_product",
        transactionId: "txn_1",
        productType: .consumable,
        isActive: true
      ),
      createMockTransaction(
        productId: "lifetime_product",
        transactionId: "txn_2",
        productType: .nonConsumable,
        isActive: true
      ),
      createMockTransaction(
        productId: "subscription_product",
        transactionId: "txn_3",
        expirationDate: Date().addingTimeInterval(3600),
        productType: .autoRenewable,
        willRenew: true,
        isInGracePeriod: false,
        isInBillingRetryPeriod: false,
        isActive: true
      )
    ]

    let (nonSubscriptions, subscriptions) = EntitlementProcessor.processTransactions(from: transactions)

    #expect(nonSubscriptions.count == 2)
    #expect(subscriptions.count == 1)

    // Check consumable non-subscription
    let consumable = nonSubscriptions.first { $0.productId == "consumable_product" }
    #expect(consumable?.isConsumable == true)
    #expect(consumable?.transactionId == "txn_1")

    // Check non-consumable non-subscription
    let lifetime = nonSubscriptions.first { $0.productId == "lifetime_product" }
    #expect(lifetime?.isConsumable == false)
    #expect(lifetime?.transactionId == "txn_2")

    // Check subscription
    let subscription = subscriptions.first
    #expect(subscription?.productId == "subscription_product")
    #expect(subscription?.transactionId == "txn_3")
    #expect(subscription?.willRenew == true)
    #expect(subscription?.isActive == true)
    #expect(subscription?.isInGracePeriod == false)
    #expect(subscription?.isInBillingRetryPeriod == false)
  }

  @Test("Process transactions separates autoRenewable and nonRenewable into subscriptions")
  func testProcessTransactions_separatesSubscriptionTypes() {
    let transactions = [
      createMockTransaction(
        productId: "auto_renewable",
        transactionId: "txn_auto",
        productType: .autoRenewable,
        willRenew: true,
        isActive: true
      ),
      createMockTransaction(
        productId: "non_renewable",
        transactionId: "txn_non_renewable",
        productType: .nonRenewable,
        willRenew: false,
        isActive: true
      )
    ]

    let (_, subscriptions) = EntitlementProcessor.processTransactions(from: transactions)

    #expect(subscriptions.count == 2)
    #expect(subscriptions.contains { $0.productId == "auto_renewable" })
    #expect(subscriptions.contains { $0.productId == "non_renewable" })
  }

  @Test("Process transactions preserves subscription state fields")
  func testProcessTransactions_preservesSubscriptionStateFields() {
    let transactions = [
      createMockTransaction(
        productId: "grace_period_sub",
        transactionId: "txn_grace",
        expirationDate: Date().addingTimeInterval(3600),
        productType: .autoRenewable,
        willRenew: true,
        isInGracePeriod: true,
        isInBillingRetryPeriod: false,
        isActive: true
      ),
      createMockTransaction(
        productId: "billing_retry_sub",
        transactionId: "txn_billing",
        expirationDate: Date().addingTimeInterval(3600),
        productType: .autoRenewable,
        willRenew: true,
        isInGracePeriod: false,
        isInBillingRetryPeriod: true,
        isActive: true
      ),
      createMockTransaction(
        productId: "revoked_sub",
        transactionId: "txn_revoked",
        expirationDate: Date().addingTimeInterval(3600),
        isRevoked: true,
        productType: .autoRenewable,
        willRenew: false,
        isInGracePeriod: false,
        isInBillingRetryPeriod: false,
        isActive: false
      )
    ]

    let (_, subscriptions) = EntitlementProcessor.processTransactions(from: transactions)

    #expect(subscriptions.count == 3)

    let gracePeriodSub = subscriptions.first { $0.productId == "grace_period_sub" }
    #expect(gracePeriodSub?.isInGracePeriod == true)
    #expect(gracePeriodSub?.isInBillingRetryPeriod == false)
    #expect(gracePeriodSub?.willRenew == true)
    #expect(gracePeriodSub?.isActive == true)

    let billingRetrySub = subscriptions.first { $0.productId == "billing_retry_sub" }
    #expect(billingRetrySub?.isInGracePeriod == false)
    #expect(billingRetrySub?.isInBillingRetryPeriod == true)
    #expect(billingRetrySub?.willRenew == true)
    #expect(billingRetrySub?.isActive == true)

    let revokedSub = subscriptions.first { $0.productId == "revoked_sub" }
    #expect(revokedSub?.isRevoked == true)
    #expect(revokedSub?.willRenew == false)
    #expect(revokedSub?.isActive == false)
  }

  @Test("Process transactions preserves revoked field for non-subscriptions")
  func testProcessTransactions_preservesRevokedFieldForNonSubscriptions() {
    let transactions = [
      createMockTransaction(
        productId: "active_lifetime",
        transactionId: "txn_active",
        isRevoked: false,
        productType: .nonConsumable
      ),
      createMockTransaction(
        productId: "revoked_lifetime",
        transactionId: "txn_revoked",
        isRevoked: true,
        productType: .nonConsumable
      )
    ]

    let (nonSubscriptions, _) = EntitlementProcessor.processTransactions(from: transactions)

    #expect(nonSubscriptions.count == 2)

    let activeLifetime = nonSubscriptions.first { $0.productId == "active_lifetime" }
    #expect(activeLifetime?.isRevoked == false)

    let revokedLifetime = nonSubscriptions.first { $0.productId == "revoked_lifetime" }
    #expect(revokedLifetime?.isRevoked == true)
  }

  // MARK: - Enhanced Processing Tests
  // Note: Testing the enhanced processing path with revoked state requires real StoreKit Transaction objects
  // which can't be easily mocked. The revoked state tracking is tested indirectly through:
  // - testProcessTransactions_preservesSubscriptionStateFields() which tests revoked flag in SubscriptionTransaction
  // - testRevokedNonConsumableDoesNotGrantLifetime() which tests revoked non-consumables don't grant lifetime access
  // - Integration tests with real StoreKit transactions that verify the full flow

  @available(iOS 15.0, *)
  @Test("Process and enhance entitlements with subscription in grace period")
  func testProcessAndEnhanceEntitlements_gracePeriod() async {
    let transaction = createMockTransaction(
      productId: "subscription_product",
      transactionId: "txn_grace",
      purchaseDate: Date(),
      originalPurchaseDate: Date(),
      expirationDate: Date().addingTimeInterval(3600),
      isRevoked: false,
      productType: .autoRenewable,
      willRenew: true,
      isInGracePeriod: true,
      isInBillingRetryPeriod: false,
      isActive: true
    )

    let entitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      productIds: Set(["subscription_product"])
    )

    let transactionsByEntitlement = ["premium": [transaction]]
    let rawEntitlementsByProductId = ["subscription_product": Set([entitlement])]
    let productIdsByEntitlementId = ["premium": Set(["subscription_product"])]

    // First process transactions to create subscription objects
    let (_, initialSubscriptions) = EntitlementProcessor.processTransactions(from: [transaction])
    var subscriptions = initialSubscriptions

    // Mock provider returns grace period state
    let mockProvider = MockSubscriptionStatusProvider(
      mockWillAutoRenew: true,
      mockState: .inGracePeriod
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: mockProvider
    )

    #expect(result.count == 1)
    let processedEntitlement = result["subscription_product"]?.first
    #expect(processedEntitlement?.id == "premium")
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.willRenew == true)

    // Verify subscription transaction was updated with grace period state
    #expect(subscriptions.count == 1)
    #expect(subscriptions.first?.isInGracePeriod == true)
    #expect(subscriptions.first?.isInBillingRetryPeriod == false)
  }

  @available(iOS 15.0, *)
  @Test("Process and enhance entitlements with subscription in billing retry")
  func testProcessAndEnhanceEntitlements_billingRetry() async {
    let transaction = createMockTransaction(
      productId: "subscription_product",
      transactionId: "txn_billing",
      purchaseDate: Date(),
      originalPurchaseDate: Date(),
      expirationDate: Date().addingTimeInterval(3600),
      isRevoked: false,
      productType: .autoRenewable,
      willRenew: true,
      isInGracePeriod: false,
      isInBillingRetryPeriod: true,
      isActive: true
    )

    let entitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      productIds: Set(["subscription_product"])
    )

    let transactionsByEntitlement = ["premium": [transaction]]
    let rawEntitlementsByProductId = ["subscription_product": Set([entitlement])]
    let productIdsByEntitlementId = ["premium": Set(["subscription_product"])]

    // First process transactions to create subscription objects
    let (_, initialSubscriptions) = EntitlementProcessor.processTransactions(from: [transaction])
    var subscriptions = initialSubscriptions

    // Mock provider returns billing retry state
    let mockProvider = MockSubscriptionStatusProvider(
      mockWillAutoRenew: true,
      mockState: .inBillingRetryPeriod
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: mockProvider
    )

    #expect(result.count == 1)
    let processedEntitlement = result["subscription_product"]?.first
    #expect(processedEntitlement?.id == "premium")
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.willRenew == true)

    // Verify subscription transaction was updated with billing retry state
    #expect(subscriptions.count == 1)
    #expect(subscriptions.first?.isInGracePeriod == false)
    #expect(subscriptions.first?.isInBillingRetryPeriod == true)
  }

  @available(iOS 15.0, *)
  @Test("Process and enhance entitlements with revoked subscription")
  func testProcessAndEnhanceEntitlements_revoked() async {
    let transaction = createMockTransaction(
      productId: "subscription_product",
      transactionId: "txn_revoked",
      purchaseDate: Date(),
      originalPurchaseDate: Date(),
      expirationDate: Date().addingTimeInterval(3600),
      isRevoked: true,
      productType: .autoRenewable,
      willRenew: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: false
    )

    let entitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      productIds: Set(["subscription_product"])
    )

    let transactionsByEntitlement = ["premium": [transaction]]
    let rawEntitlementsByProductId = ["subscription_product": Set([entitlement])]
    let productIdsByEntitlementId = ["premium": Set(["subscription_product"])]

    // First process transactions to create subscription objects
    let (_, initialSubscriptions) = EntitlementProcessor.processTransactions(from: [transaction])
    var subscriptions = initialSubscriptions

    // Mock provider returns revoked state
    let mockProvider = MockSubscriptionStatusProvider(
      mockWillAutoRenew: false,
      mockState: .revoked
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: mockProvider
    )

    #expect(result.count == 1)
    let processedEntitlement = result["subscription_product"]?.first
    #expect(processedEntitlement?.id == "premium")
    #expect(processedEntitlement?.isActive == false)
    #expect(processedEntitlement?.willRenew == false)

    // Verify subscription transaction was created with revoked state
    #expect(subscriptions.count == 1)
    #expect(subscriptions.first?.isRevoked == true)
    #expect(subscriptions.first?.willRenew == false)
    #expect(subscriptions.first?.isActive == false)
  }

  // MARK: - No Transactions Tests

  @Test("Process with no transactions but single inactive entitlement")
  func testProcessNoTransactionsSingleEntitlement() {
    let entitlement = createEntitlement(
      id: "entitlement_1",
      productIds: ["product_a"]
    )

    let transactionsByEntitlement: [String: [MockTransaction]] = [:] // No transactions
    let rawEntitlementsByProductId = ["product_a": Set([entitlement])]
    let productIdsByEntitlementId: [String: Set<String>] = [:]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // Should return the entitlement even without transactions (as inactive)
    #expect(result["product_a"]?.count == 1)
    #expect(result["product_a"]?.first?.id == "entitlement_1")
    #expect(result["product_a"]?.first?.isActive == false)
  }

  @Test("Process with no transactions but multiple inactive entitlements")
  func testProcessNoTransactionsMultipleEntitlements() {
    let entitlement1 = createEntitlement(
      id: "entitlement_1",
      productIds: ["product_a"]
    )
    let entitlement2 = createEntitlement(
      id: "entitlement_2",
      productIds: ["product_b"]
    )
    let entitlement3 = createEntitlement(
      id: "entitlement_3",
      productIds: ["product_c"]
    )

    let transactionsByEntitlement: [String: [MockTransaction]] = [:] // No transactions
    let rawEntitlementsByProductId = [
      "product_a": Set([entitlement1]),
      "product_b": Set([entitlement2]),
      "product_c": Set([entitlement3])
    ]
    let productIdsByEntitlementId: [String: Set<String>] = [:]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // Should return all entitlements even without transactions (all inactive)
    #expect(result["product_a"]?.count == 1)
    #expect(result["product_a"]?.first?.id == "entitlement_1")
    #expect(result["product_a"]?.first?.isActive == false)

    #expect(result["product_b"]?.count == 1)
    #expect(result["product_b"]?.first?.id == "entitlement_2")
    #expect(result["product_b"]?.first?.isActive == false)

    #expect(result["product_c"]?.count == 1)
    #expect(result["product_c"]?.first?.id == "entitlement_3")
    #expect(result["product_c"]?.first?.isActive == false)
  }

  @Test("Process with no transactions but entitlement with multiple products")
  func testProcessNoTransactionsEntitlementMultipleProducts() {
    let entitlement = createEntitlement(
      id: "premium_tier",
      productIds: ["monthly", "annual", "lifetime"]
    )

    let transactionsByEntitlement: [String: [MockTransaction]] = [:] // No transactions
    let rawEntitlementsByProductId = [
      "monthly": Set([entitlement]),
      "annual": Set([entitlement]),
      "lifetime": Set([entitlement])
    ]
    let productIdsByEntitlementId: [String: Set<String>] = [:]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // Should return the same entitlement for all products (all inactive)
    #expect(result["monthly"]?.count == 1)
    #expect(result["monthly"]?.first?.id == "premium_tier")
    #expect(result["monthly"]?.first?.isActive == false)

    #expect(result["annual"]?.count == 1)
    #expect(result["annual"]?.first?.id == "premium_tier")
    #expect(result["annual"]?.first?.isActive == false)

    #expect(result["lifetime"]?.count == 1)
    #expect(result["lifetime"]?.first?.id == "premium_tier")
    #expect(result["lifetime"]?.first?.isActive == false)
  }

  @Test("Process with no transactions and multiple entitlements per product")
  func testProcessNoTransactionsMultipleEntitlementsPerProduct() {
    let entitlement1 = createEntitlement(
      id: "basic_tier",
      productIds: ["product_a"]
    )
    let entitlement2 = createEntitlement(
      id: "premium_tier",
      productIds: ["product_a"]
    )

    let transactionsByEntitlement: [String: [MockTransaction]] = [:] // No transactions
    let rawEntitlementsByProductId = [
      "product_a": Set([entitlement1, entitlement2])
    ]
    let productIdsByEntitlementId: [String: Set<String>] = [:]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // Should return both entitlements for the product (all inactive)
    #expect(result["product_a"]?.count == 2)
    let entitlementIds = result["product_a"]?.map { $0.id } ?? []
    #expect(entitlementIds.contains("basic_tier"))
    #expect(entitlementIds.contains("premium_tier"))

    // All should be inactive
    let allInactive = result["product_a"]?.allSatisfy { !$0.isActive } ?? false
    #expect(allInactive)
  }

  // MARK: - ProductIds From Server Config Tests

  @Test("ProductIds contains all products from server config, not just transacted products")
  func testProductIdsContainsAllFromServerConfig() {
    // This test verifies the fix where productIds should contain ALL product IDs
    // from server config that unlock the entitlement, not just the ones with transactions.

    // Server config says products A, B, and C all unlock "premium" entitlement
    let entitlement = createEntitlement(
      id: "premium",
      productIds: ["product_a", "product_b", "product_c"]
    )

    // User only has a transaction for product_a
    let transaction = createMockTransaction(
      productId: "product_a",
      productType: .nonConsumable
    )

    let transactionsByEntitlement = ["premium": [transaction]]
    let rawEntitlementsByProductId = [
      "product_a": Set([entitlement]),
      "product_b": Set([entitlement]),
      "product_c": Set([entitlement])
    ]
    // This is the key - server config says all 3 products unlock premium
    let productIdsByEntitlementId = ["premium": Set(["product_a", "product_b", "product_c"])]

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )

    // The entitlement's productIds should contain ALL products from server config,
    // not just product_a which had the transaction
    let processedEntitlement = result["product_a"]?.first
    #expect(processedEntitlement?.productIds == Set(["product_a", "product_b", "product_c"]))
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.isLifetime == true)

    // Also verify the entitlement is returned for all products
    #expect(result["product_b"]?.first?.productIds == Set(["product_a", "product_b", "product_c"]))
    #expect(result["product_c"]?.first?.productIds == Set(["product_a", "product_b", "product_c"]))
  }
}

// MARK: - Protocol Adapter Tests

// MARK: - Mock Subscription Status Provider

@available(iOS 15.0, *)
struct MockSubscriptionStatusProvider: SubscriptionStatusProvider {
  var mockWillAutoRenew: Bool
  var mockState: LatestSubscription.State?
  var mockOfferType: LatestSubscription.OfferType?

  init(
    mockWillAutoRenew: Bool = true,
    mockState: LatestSubscription.State? = .subscribed,
    mockOfferType: LatestSubscription.OfferType? = nil
  ) {
    self.mockWillAutoRenew = mockWillAutoRenew
    self.mockState = mockState
    self.mockOfferType = mockOfferType
  }

  func getSubscriptionStatus(for transaction: Transaction) async -> StoreKit.Product.SubscriptionInfo.Status? {
    return nil // Simplified for testing
  }

  func getWillAutoRenew(from status: StoreKit.Product.SubscriptionInfo.Status?) -> Bool {
    return mockWillAutoRenew
  }

  func getSubscriptionState(from status: StoreKit.Product.SubscriptionInfo.Status?) -> LatestSubscription.State? {
    return mockState
  }

  @available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *)
  func getOfferType(from transaction: Transaction) -> LatestSubscription.OfferType? {
    return mockOfferType
  }
}

