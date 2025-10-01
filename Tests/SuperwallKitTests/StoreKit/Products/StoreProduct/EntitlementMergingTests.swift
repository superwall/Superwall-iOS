//
//  EntitlementMergingTests.swift
//  SuperwallKitTests
//
//  Created by Claude Code on 24/09/2025.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite("Entitlement Merging Tests")
struct EntitlementMergingTests {

@Test("Lifetime entitlement takes priority over non-lifetime")
func testLifetimeTakesPriority() {
  let lifetimeEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    isLifetime: true
  )

  let subscriptionEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: Date().addingTimeInterval(3600), // Expires in 1 hour
    isLifetime: false,
    willRenew: true
  )

  #expect(lifetimeEntitlement.shouldTakePriorityOver(subscriptionEntitlement))
  #expect(!subscriptionEntitlement.shouldTakePriorityOver(lifetimeEntitlement))

  let merged = Entitlement.mergePrioritized([lifetimeEntitlement, subscriptionEntitlement])
  #expect(merged.count == 1)
  #expect(merged.first?.isLifetime == true)
}

@Test("Active entitlement takes priority over inactive")
func testActiveTakesPriority() {
  let activeEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: Date().addingTimeInterval(3600)
  )

  let inactiveEntitlement = Entitlement(
    id: "premium",
    isActive: false,
    expiresAt: Date().addingTimeInterval(-3600) // Expired
  )

  #expect(activeEntitlement.shouldTakePriorityOver(inactiveEntitlement))
  #expect(!inactiveEntitlement.shouldTakePriorityOver(activeEntitlement))

  let merged = Entitlement.mergePrioritized([activeEntitlement, inactiveEntitlement])
  #expect(merged.count == 1)
  #expect(merged.first?.isActive == true)
}

@Test("Non-revoked entitlement takes priority over revoked")
func testNonRevokedTakesPriority() {
  let normalEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    state: .subscribed // Not revoked
  )

  let revokedEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    state: .revoked
  )

  #expect(normalEntitlement.shouldTakePriorityOver(revokedEntitlement))
  #expect(!revokedEntitlement.shouldTakePriorityOver(normalEntitlement))

  let merged = Entitlement.mergePrioritized([normalEntitlement, revokedEntitlement])
  #expect(merged.count == 1)
  #expect(merged.first?.isRevoked == false)
}

@Test("Later expiry time takes priority")
func testLaterExpiryTakesPriority() {
  let futureDate = Date().addingTimeInterval(7200) // 2 hours
  let nearerFutureDate = Date().addingTimeInterval(3600) // 1 hour

  let longerEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: futureDate
  )

  let shorterEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: nearerFutureDate
  )

  #expect(longerEntitlement.shouldTakePriorityOver(shorterEntitlement))
  #expect(!shorterEntitlement.shouldTakePriorityOver(longerEntitlement))

  let merged = Entitlement.mergePrioritized([longerEntitlement, shorterEntitlement])
  #expect(merged.count == 1)
  #expect(merged.first?.expiresAt == futureDate)
}

@Test("Will renew takes priority over won't renew")
func testWillRenewTakesPriority() {
  let futureDate = Date().addingTimeInterval(3600)

  let renewingEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: futureDate,
    willRenew: true
  )

  let nonRenewingEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: futureDate,
    willRenew: false
  )

  #expect(renewingEntitlement.shouldTakePriorityOver(nonRenewingEntitlement))
  #expect(!nonRenewingEntitlement.shouldTakePriorityOver(renewingEntitlement))

  let merged = Entitlement.mergePrioritized([renewingEntitlement, nonRenewingEntitlement])
  #expect(merged.count == 1)
  #expect(merged.first?.willRenew == true)
}

@Test("Not in grace period takes priority over in grace period")
func testNotInGracePeriodTakesPriority() {
  let futureDate = Date().addingTimeInterval(3600)

  let normalEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: futureDate,
    willRenew: true,
    state: nil // Not in grace period
  )

  let gracePeriodEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: futureDate,
    willRenew: true,
    state: .inGracePeriod
  )

  #expect(normalEntitlement.shouldTakePriorityOver(gracePeriodEntitlement))
  #expect(!gracePeriodEntitlement.shouldTakePriorityOver(normalEntitlement))

  let merged = Entitlement.mergePrioritized([normalEntitlement, gracePeriodEntitlement])
  #expect(merged.count == 1)
  #expect(merged.first?.isInGracePeriod == nil)
}

@Test("Complex priority scenario")
func testComplexPriorityScenario() {
  // Device has an active subscription that expires soon but will renew
  let deviceEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    expiresAt: Date().addingTimeInterval(1800), // 30 minutes
    willRenew: true
  )

  // Web has a lifetime entitlement (highest priority)
  let webLifetimeEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    isLifetime: true
  )

  // Web also has an expired subscription (lowest priority)
  let webExpiredEntitlement = Entitlement(
    id: "premium",
    isActive: false,
    expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
    willRenew: false
  )

  let merged = Entitlement.mergePrioritized([
    deviceEntitlement,
    webLifetimeEntitlement,
    webExpiredEntitlement
  ])

  #expect(merged.count == 1)
  let result = merged.first!
  #expect(result.id == "premium")
  #expect(result.isLifetime == true)
  #expect(result.isActive == true)
}

@Test("Different entitlement IDs are preserved")
func testDifferentEntitlementIDsPreserved() {
  let premiumEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    isLifetime: true
  )

  let basicEntitlement = Entitlement(
    id: "basic",
    isActive: true,
    expiresAt: Date().addingTimeInterval(3600)
  )

  let proEntitlement = Entitlement(
    id: "pro",
    isActive: false
  )

  let merged = Entitlement.mergePrioritized([
    premiumEntitlement,
    basicEntitlement,
    proEntitlement
  ])

  #expect(merged.count == 3)

  let entitlementIds = Set(merged.map { $0.id })
  #expect(entitlementIds.contains("premium"))
  #expect(entitlementIds.contains("basic"))
  #expect(entitlementIds.contains("pro"))
}

@Test("Merge preserves product IDs and other metadata")
func testMergePreservesMetadata() {
  let deviceEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    productIds: Set(["monthly_premium"]),
    latestProductId: "monthly_premium",
    startsAt: Date().addingTimeInterval(-86400), // Started 1 day ago
    expiresAt: Date().addingTimeInterval(3600), // Expires in 1 hour
    willRenew: true
  )

  let webEntitlement = Entitlement(
    id: "premium",
    isActive: true,
    productIds: Set(["lifetime_premium"]),
    latestProductId: "lifetime_premium",
    startsAt: Date().addingTimeInterval(-172800), // Started 2 days ago
    isLifetime: true
  )

  let merged = Entitlement.mergePrioritized([deviceEntitlement, webEntitlement])

  #expect(merged.count == 1)
  let result = merged.first!

  // Lifetime should win
  #expect(result.isLifetime == true)
  #expect(result.latestProductId == "lifetime_premium")
  #expect(result.productIds == Set(["lifetime_premium"]))
  #expect(abs(result.startsAt!.timeIntervalSince(Date().addingTimeInterval(-172800))) < 1)
}

}