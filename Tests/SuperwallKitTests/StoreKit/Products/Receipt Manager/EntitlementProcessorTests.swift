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
    isActive: Bool = false
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
      isActive: isActive
    )
  }
  
  private func createEntitlement(
    id: String = "test_entitlement",
    productIds: Set<String> = ["test_product"]
  ) -> Entitlement {
    return Entitlement(
      id: id,
      type: .serviceLevel,
      productIds: productIds
    )
  }
  
  // MARK: - Basic Processing Tests
  
  @Test("Process empty transactions returns empty entitlements")
  func testProcessEmptyTransactions() {
    let transactionsByEntitlement: [String: [any EntitlementTransaction]] = [:]
    let rawEntitlementsByProductId: [String: Set<Entitlement>] = [:]
    
    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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
    
    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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
    
    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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
    
    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )
    
    let processedEntitlement = result["expired_product"]?.first
    #expect(processedEntitlement?.isActive == false)
    #expect(processedEntitlement?.expiresAt == pastDate)
  }
  
  @Test("Process revoked transaction")
  func testProcessRevokedTransaction() {
    let transaction = createMockTransaction(
      productId: "revoked_product",
      isRevoked: true,
      productType: .nonConsumable
    )
    
    let entitlement = createEntitlement(
      id: "revoked_entitlement",
      productIds: ["revoked_product"]
    )
    
    let transactionsByEntitlement = ["revoked_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["revoked_product": Set([entitlement])]
    
    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )
    
    let processedEntitlement = result["revoked_product"]?.first
    #expect(processedEntitlement?.isActive == false)
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
    
    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )

    let processedEntitlement = result["renewal_product"]?.first
    #expect(processedEntitlement?.startsAt == originalDate)
    #expect(processedEntitlement?.renewedAt == renewalDate)
  }
  
  // MARK: - Multiple Product Tests
  
  @Test("Process entitlement with multiple products")
  func testProcessMultipleProducts() {
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
    
    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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
      productType: .nonConsumable
    )
    
    let entitlement = createEntitlement(
      id: "non_consumable_entitlement",
      productIds: ["non_consumable"]
    )
    
    let transactionsByEntitlement = ["non_consumable_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["non_consumable": Set([entitlement])]
    
    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )
    
    let processedEntitlement = result["non_consumable"]?.first
    #expect(processedEntitlement?.isActive == true)
    #expect(processedEntitlement?.expiresAt == nil)
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )

    let processedEntitlement = result["consumable"]?.first
    // Consumables without expiration dates should not be considered active
    #expect(processedEntitlement?.isActive == false)
  }

  // MARK: - Complex Scenarios

  @Test("Process renewal transaction with different dates")
  func testProcessRenewalWithDifferentDates() {
    let baseDate = Date()
    let originalDate = baseDate.addingTimeInterval(-3600) // 1 hour ago
    let renewalDate = baseDate // Now

    let transaction = createMockTransaction(
      productId: "renewal_product",
      purchaseDate: renewalDate,
      originalPurchaseDate: originalDate,
      expirationDate: baseDate.addingTimeInterval(3600),
      productType: .autoRenewable,
      isActive: true
    )

    let entitlement = createEntitlement(
      id: "renewal_entitlement",
      productIds: ["renewal_product"]
    )

    let transactionsByEntitlement = ["renewal_entitlement": [transaction]]
    let rawEntitlementsByProductId = ["renewal_product": Set([entitlement])]

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )

    let processedEntitlement = result["renewal_product"]?.first
    #expect(processedEntitlement?.startsAt == originalDate)
    #expect(processedEntitlement?.renewedAt == renewalDate)
    #expect(processedEntitlement?.isActive == true)
  }

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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )

    // Should be active due to lifetime product, even with expired subscription
    let lifetimeResult = result["lifetime_product"]?.first
    let subscriptionResult = result["subscription_product"]?.first

    #expect(lifetimeResult?.isActive == true)
    #expect(lifetimeResult?.isLifetime == true)
    #expect(lifetimeResult?.latestProductId == "lifetime_product")
    #expect(subscriptionResult?.isActive == true) // Active due to lifetime in same entitlement
    #expect(subscriptionResult?.isLifetime == true)
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )

    // Should return empty sets for each product when entitlement IDs don't match
    // The processor finds raw entitlements for the product but filters out those with mismatched IDs
    #expect(result["product_a"]?.isEmpty == true)
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
        expirationDate: baseDate.addingTimeInterval(3600), // 1 hour (latest)
        isRevoked: false,
        productType: .autoRenewable
      ),
      createMockTransaction(
        productId: "product3",
        transactionId: "txn_3",
        expirationDate: baseDate.addingTimeInterval(900), // 15 min
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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
    }

    let result = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
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

  // MARK: - Enhanced Processing Tests

  @available(iOS 15.0, *)
  @Test("Process and enhance entitlements with mock subscription status")
  func testProcessAndEnhanceEntitlements() async {
    let transaction = createMockTransaction(
      productId: "subscription_product",
      transactionId: "txn_123",
      purchaseDate: Date(),
      originalPurchaseDate: Date(),
      expirationDate: Date().addingTimeInterval(86400),
      isRevoked: false,
      productType: .autoRenewable,
      willRenew: true,
      renewedAt: nil as Date?,
      isInGracePeriod: false,
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
    var subscriptions: [SubscriptionTransaction] = []

    let mockProvider = MockSubscriptionStatusProvider()

    // First test basic processing to debug
    let basicResult = EntitlementProcessor.processEntitlements(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId
    )

    let basicEntitlement = basicResult["subscription_product"]?.first
    #expect(basicEntitlement?.willRenew == true, "Basic processing should preserve willRenew from mock transaction")

    let result = await EntitlementProcessor.processAndEnhanceEntitlements(
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
    #expect(processedEntitlement?.willRenew == true, "Enhanced processing should preserve willRenew from mock transaction")
  }
}

// MARK: - Protocol Adapter Tests

// MARK: - Mock Subscription Status Provider

@available(iOS 15.0, *)
struct MockSubscriptionStatusProvider: SubscriptionStatusProvider {
  var mockWillAutoRenew: Bool = true
  var mockState: LatestSubscription.State? = .subscribed
  var mockOfferType: LatestSubscription.OfferType?

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

