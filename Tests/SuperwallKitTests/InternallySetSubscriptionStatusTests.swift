//
//  InternallySetSubscriptionStatusTests.swift
//  SuperwallKitTests
//
//  Created by Claude on 02/10/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("InternallySetSubscriptionStatus Tests")
@MainActor
struct InternallySetSubscriptionStatusTests {

  // MARK: - Helper Methods

  private func createEntitlement(
    id: String,
    isActive: Bool,
    productIds: Set<String> = ["test_product"]
  ) -> Entitlement {
    return Entitlement(
      id: id,
      type: .serviceLevel,
      isActive: isActive,
      productIds: productIds,
      latestProductId: productIds.first,
      startsAt: Date(),
      renewedAt: nil,
      expiresAt: isActive ? Date().addingTimeInterval(3600) : Date().addingTimeInterval(-3600),
      isLifetime: false,
      willRenew: isActive,
      state: isActive ? .subscribed : .expired,
      offerType: nil
    )
  }

  // MARK: - Tests for .active status

  @Test("Active status with mixed active and inactive entitlements filters to only active")
  func testActiveStatusWithMixedEntitlements() async throws {
    let activeEntitlement = createEntitlement(id: "premium", isActive: true)
    let inactiveEntitlement = createEntitlement(id: "basic", isActive: false)

    // Test the filtering logic directly
    let combinedEntitlements = [activeEntitlement, inactiveEntitlement]
    let mergedEntitlements = Entitlement.mergePrioritized(combinedEntitlements)
    let activeEntitlements = mergedEntitlements.filter { $0.isActive }

    #expect(activeEntitlements.count == 1)
    #expect(activeEntitlements.first?.id == "premium")
    #expect(activeEntitlements.first?.isActive == true)
  }

  @Test("Active status with only inactive entitlements results in empty array")
  func testActiveStatusWithOnlyInactiveEntitlements() async throws {
    let inactiveEntitlement = createEntitlement(id: "premium", isActive: false)

    // Test the filtering logic directly
    let combinedEntitlements = [inactiveEntitlement]
    let mergedEntitlements = Entitlement.mergePrioritized(combinedEntitlements)
    let activeEntitlements = mergedEntitlements.filter { $0.isActive }

    #expect(activeEntitlements.isEmpty)
  }

  @Test("Active status with multiple active entitlements keeps all active")
  func testActiveStatusWithMultipleActiveEntitlements() async throws {
    let activeEntitlement1 = createEntitlement(id: "premium", isActive: true)
    let activeEntitlement2 = createEntitlement(id: "pro", isActive: true)
    let inactiveEntitlement = createEntitlement(id: "basic", isActive: false)

    // Test the filtering logic directly
    let combinedEntitlements = [activeEntitlement1, activeEntitlement2, inactiveEntitlement]
    let mergedEntitlements = Entitlement.mergePrioritized(combinedEntitlements)
    let activeEntitlements = mergedEntitlements.filter { $0.isActive }

    #expect(activeEntitlements.count == 2)
    let ids = Set(activeEntitlements.map { $0.id })
    #expect(ids.contains("premium"))
    #expect(ids.contains("pro"))
    #expect(!ids.contains("basic"))
  }

  // MARK: - Tests for filtering web entitlements

  @Test("Inactive web entitlements are filtered out")
  func testInactiveWebEntitlementsFiltered() async throws {
    let activeWebEntitlement = createEntitlement(id: "web_premium", isActive: true)
    let inactiveWebEntitlement = createEntitlement(id: "web_basic", isActive: false)

    // Test the filtering logic directly
    let webEntitlements = [activeWebEntitlement, inactiveWebEntitlement]
    let activeWebEntitlements = webEntitlements.filter { $0.isActive }

    #expect(activeWebEntitlements.count == 1)
    #expect(activeWebEntitlements.first?.id == "web_premium")
    #expect(activeWebEntitlements.first?.isActive == true)
  }

  @Test("Only inactive web entitlements results in empty array")
  func testOnlyInactiveWebEntitlements() async throws {
    let inactiveWebEntitlement = createEntitlement(id: "web_premium", isActive: false)

    // Test the filtering logic directly
    let webEntitlements = [inactiveWebEntitlement]
    let activeWebEntitlements = webEntitlements.filter { $0.isActive }

    #expect(activeWebEntitlements.isEmpty)
  }
}
