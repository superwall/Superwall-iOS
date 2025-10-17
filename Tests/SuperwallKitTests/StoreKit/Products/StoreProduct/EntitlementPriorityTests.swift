//
//  EntitlementPriorityTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 10/10/2025.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Comprehensive tests for Entitlement.shouldTakePriorityOver() function.
///
/// Priority order (highest to lowest):
/// 1. Active entitlements (isActive = true)
/// 2. Lifetime entitlements (isLifetime = true)
/// 3. Non-revoked entitlements (isRevoked = false)
/// 4. Latest expiry time (furthest future expiresAt)
/// 5. Will renew vs won't renew (willRenew = true)
/// 6. Not in grace period vs in grace period (isInGracePeriod = false)
@Suite("Entitlement Priority Tests")
struct EntitlementPriorityTests {

  // MARK: - Basic ID Validation

  @Test("Returns false when comparing different entitlement IDs")
  func testDifferentIdReturnsFalse() {
    let entitlement1 = Entitlement(id: "premium", isActive: true)
    let entitlement2 = Entitlement(id: "pro", isActive: true)

    #expect(!entitlement1.shouldTakePriorityOver(entitlement2))
    #expect(!entitlement2.shouldTakePriorityOver(entitlement1))
  }

  @Test("Returns false when both entitlements are identical")
  func testIdenticalEntitlementsReturnsFalse() {
    let date = Date()
    let entitlement1 = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true
    )
    let entitlement2 = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true
    )

    #expect(!entitlement1.shouldTakePriorityOver(entitlement2))
    #expect(!entitlement2.shouldTakePriorityOver(entitlement1))
  }

  // MARK: - Priority 1: Active Status

  @Test("Active takes priority over inactive")
  func testActivePriorityOverInactive() {
    let active = Entitlement(id: "premium", isActive: true, isLifetime: false)
    let inactive = Entitlement(id: "premium", isActive: false, isLifetime: false)

    #expect(active.shouldTakePriorityOver(inactive))
    #expect(!inactive.shouldTakePriorityOver(active))
  }

  @Test("Active subscription takes priority over inactive lifetime")
  func testActiveSubscriptionPriorityOverInactiveLifetime() {
    let activeSubscription = Entitlement(id: "premium", isActive: true, isLifetime: false)
    let inactiveLifetime = Entitlement(id: "premium", isActive: false, isLifetime: true)

    // Active status is checked first, so active subscription wins
    #expect(activeSubscription.shouldTakePriorityOver(inactiveLifetime))
    #expect(!inactiveLifetime.shouldTakePriorityOver(activeSubscription))
  }

  @Test("Active with near expiry takes priority over inactive with far expiry")
  func testActiveNearExpiryPriorityOverInactiveFarExpiry() {
    let activeNearExpiry = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(60) // Expires in 1 minute
    )
    let inactiveFarExpiry = Entitlement(
      id: "premium",
      isActive: false,
      expiresAt: Date().addingTimeInterval(-3600) // Expired 1 hour ago
    )

    #expect(activeNearExpiry.shouldTakePriorityOver(inactiveFarExpiry))
    #expect(!inactiveFarExpiry.shouldTakePriorityOver(activeNearExpiry))
  }

  @Test("Both active continue to next priority check (lifetime)")
  func testBothActiveContinueToLifetimeCheck() {
    let activeLifetime = Entitlement(id: "premium", isActive: true, isLifetime: true)
    let activeSubscription = Entitlement(id: "premium", isActive: true, isLifetime: false)

    // Should fall through to lifetime check
    #expect(activeLifetime.shouldTakePriorityOver(activeSubscription))
    #expect(!activeSubscription.shouldTakePriorityOver(activeLifetime))
  }

  @Test("Both inactive continue to next priority check (lifetime)")
  func testBothInactiveContinueToLifetimeCheck() {
    let inactiveLifetime = Entitlement(id: "premium", isActive: false, isLifetime: true)
    let inactiveSubscription = Entitlement(id: "premium", isActive: false, isLifetime: false)

    // Should fall through to lifetime check
    #expect(inactiveLifetime.shouldTakePriorityOver(inactiveSubscription))
    #expect(!inactiveSubscription.shouldTakePriorityOver(inactiveLifetime))
  }

  // MARK: - Priority 2: Lifetime

  @Test("Lifetime takes priority over non-lifetime when both active")
  func testLifetimePriorityOverNonLifetimeWhenBothActive() {
    let lifetime = Entitlement(id: "premium", isActive: true, isLifetime: true)
    let subscription = Entitlement(id: "premium", isActive: true, isLifetime: false)

    #expect(lifetime.shouldTakePriorityOver(subscription))
    #expect(!subscription.shouldTakePriorityOver(lifetime))
  }

  @Test("Lifetime with nil isLifetime treated as false")
  func testLifetimeNilTreatedAsFalse() {
    let lifetimeNil = Entitlement(id: "premium", isActive: true, isLifetime: nil)
    let lifetimeTrue = Entitlement(id: "premium", isActive: true, isLifetime: true)

    #expect(lifetimeTrue.shouldTakePriorityOver(lifetimeNil))
    #expect(!lifetimeNil.shouldTakePriorityOver(lifetimeTrue))
  }

  @Test("Both active and lifetime with no other differences returns false")
  func testBothActiveAndLifetimeReturnsfalse() {
    let lifetime1 = Entitlement(id: "premium", isActive: true, isLifetime: true, state: nil)
    let lifetime2 = Entitlement(id: "premium", isActive: true, isLifetime: true, state: nil)

    // Both active, both lifetime, both have nil state (normal for lifetime)
    // Should return false (no preference)
    #expect(!lifetime1.shouldTakePriorityOver(lifetime2))
    #expect(!lifetime2.shouldTakePriorityOver(lifetime1))
  }

  // MARK: - Priority 3: Revoked Status

  @Test("Non-revoked takes priority over revoked when both active")
  func testNonRevokedPriorityOverRevoked() {
    let notRevoked = Entitlement(id: "premium", isActive: true, state: .subscribed)
    let revoked = Entitlement(id: "premium", isActive: true, state: .revoked)

    #expect(notRevoked.shouldTakePriorityOver(revoked))
    #expect(!revoked.shouldTakePriorityOver(notRevoked))
  }

  @Test("Nil state treated as not revoked")
  func testNilStateTreatedAsNotRevoked() {
    let nilState = Entitlement(id: "premium", isActive: true, state: nil)
    let revoked = Entitlement(id: "premium", isActive: true, state: .revoked)

    #expect(nilState.shouldTakePriorityOver(revoked))
    #expect(!revoked.shouldTakePriorityOver(nilState))
  }

  @Test("In grace period state is not revoked")
  func testInGracePeriodNotRevoked() {
    let inGracePeriod = Entitlement(id: "premium", isActive: true, state: .inGracePeriod)
    let revoked = Entitlement(id: "premium", isActive: true, state: .revoked)

    #expect(inGracePeriod.shouldTakePriorityOver(revoked))
    #expect(!revoked.shouldTakePriorityOver(inGracePeriod))
  }

  @Test("Expired state is not revoked")
  func testExpiredStateNotRevoked() {
    let expired = Entitlement(id: "premium", isActive: true, state: .expired)
    let revoked = Entitlement(id: "premium", isActive: true, state: .revoked)

    #expect(expired.shouldTakePriorityOver(revoked))
    #expect(!revoked.shouldTakePriorityOver(expired))
  }

  // MARK: - Priority 4: Expiry Date

  @Test("Later expiry takes priority when both have expiry dates")
  func testLaterExpiryPriority() {
    let later = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(7200)
    )
    let earlier = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(3600)
    )

    #expect(later.shouldTakePriorityOver(earlier))
    #expect(!earlier.shouldTakePriorityOver(later))
  }

  @Test("Far future expiry takes priority over near future")
  func testFarFutureExpiryPriority() {
    let farFuture = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(86400 * 365) // 1 year
    )
    let nearFuture = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(86400) // 1 day
    )

    #expect(farFuture.shouldTakePriorityOver(nearFuture))
    #expect(!nearFuture.shouldTakePriorityOver(farFuture))
  }

  @Test("Future expiry takes priority over past expiry")
  func testFutureExpiryPriorityOverPastExpiry() {
    let future = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(3600)
    )
    let past = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(-3600)
    )

    #expect(future.shouldTakePriorityOver(past))
    #expect(!past.shouldTakePriorityOver(future))
  }

  @Test("Entitlement with expiry takes priority over nil expiry when both not lifetime")
  func testExpiryPriorityOverNilExpiry() {
    let withExpiry = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(3600),
      isLifetime: false
    )
    let nilExpiry = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: nil,
      isLifetime: false
    )

    #expect(withExpiry.shouldTakePriorityOver(nilExpiry))
    #expect(!nilExpiry.shouldTakePriorityOver(withExpiry))
  }

  // TODO: CHeck that its right that nil is never prioritised

  @Test("Both nil expiry continue to next priority check")
  func testBothNilExpiryContinueToNextCheck() {
    let willRenew = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: nil,
      willRenew: true
    )
    let wontRenew = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: nil,
      willRenew: false
    )

    // Should fall through to willRenew check
    #expect(willRenew.shouldTakePriorityOver(wontRenew))
    #expect(!wontRenew.shouldTakePriorityOver(willRenew))
  }

  // MARK: - Priority 5: Will Renew

  @Test("Will renew takes priority over won't renew")
  func testWillRenewPriority() {
    let date = Date().addingTimeInterval(3600)
    let willRenew = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true
    )
    let wontRenew = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: false
    )

    #expect(willRenew.shouldTakePriorityOver(wontRenew))
    #expect(!wontRenew.shouldTakePriorityOver(willRenew))
  }

  @Test("Having willRenew information takes priority over nil")
  func testWillRenewInformationTakesPriorityOverNil() {
    let date = Date().addingTimeInterval(3600)
    let willRenewTrue = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true
    )
    let willRenewFalse = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: false
    )
    let willRenewNil = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: nil
    )

    // Having information (true or false) takes priority over nil
    #expect(willRenewTrue.shouldTakePriorityOver(willRenewNil))
    #expect(!willRenewNil.shouldTakePriorityOver(willRenewTrue))
    #expect(willRenewFalse.shouldTakePriorityOver(willRenewNil))
    #expect(!willRenewNil.shouldTakePriorityOver(willRenewFalse))
  }

  // MARK: - Priority 6: Grace Period

  @Test("Not in grace period takes priority over in grace period")
  func testNotInGracePeriodPriority() {
    let date = Date().addingTimeInterval(3600)
    let notInGracePeriod = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: .subscribed
    )
    let inGracePeriod = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: .inGracePeriod
    )

    #expect(notInGracePeriod.shouldTakePriorityOver(inGracePeriod))
    #expect(!inGracePeriod.shouldTakePriorityOver(notInGracePeriod))
  }

  @Test("Having state information takes priority over nil state")
  func testHavingStateTakesPriorityOverNilState() {
    let date = Date().addingTimeInterval(3600)
    let nilState = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: nil
    )
    let inGracePeriod = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: .inGracePeriod
    )
    let subscribed = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: .subscribed
    )

    // Having state information (even grace period) takes priority over nil
    #expect(inGracePeriod.shouldTakePriorityOver(nilState))
    #expect(!nilState.shouldTakePriorityOver(inGracePeriod))
    #expect(subscribed.shouldTakePriorityOver(nilState))
    #expect(!nilState.shouldTakePriorityOver(subscribed))
  }

  @Test("Subscribed state not in grace period")
  func testSubscribedStateNotInGracePeriod() {
    let date = Date().addingTimeInterval(3600)
    let subscribed = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: .subscribed
    )
    let inGracePeriod = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: .inGracePeriod
    )

    #expect(subscribed.shouldTakePriorityOver(inGracePeriod))
    #expect(!inGracePeriod.shouldTakePriorityOver(subscribed))
  }

  @Test("Both not in grace period returns false")
  func testBothNotInGracePeriodReturnsFalse() {
    let date = Date().addingTimeInterval(3600)
    let entitlement1 = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: .subscribed
    )
    let entitlement2 = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      willRenew: true,
      state: .subscribed
    )

    // All criteria equal, should return false
    #expect(!entitlement1.shouldTakePriorityOver(entitlement2))
    #expect(!entitlement2.shouldTakePriorityOver(entitlement1))
  }

  // MARK: - Complex Scenarios

  @Test("Active overrides all other factors")
  func testActiveOverridesAllFactors() {
    let active = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(-86400), // Expired
      isLifetime: false,
      willRenew: false,
      state: .revoked
    )
    let inactive = Entitlement(
      id: "premium",
      isActive: false,
      expiresAt: Date().addingTimeInterval(86400 * 365), // Far future
      isLifetime: true, // Lifetime
      willRenew: true,
      state: .subscribed
    )

    // Active wins even though inactive has better everything else
    #expect(active.shouldTakePriorityOver(inactive))
    #expect(!inactive.shouldTakePriorityOver(active))
  }

  @Test("Lifetime overrides all factors except active status")
  func testLifetimeOverridesAllExceptActive() {
    let activeSubscription = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(3600), // Short expiry
      isLifetime: false,
      willRenew: false,
      state: .revoked
    )
    let inactiveLifetime = Entitlement(
      id: "premium",
      isActive: false,
      expiresAt: nil,
      isLifetime: true,
      willRenew: nil,
      state: .subscribed
    )

    // Active wins even though lifetime has better other factors
    #expect(activeSubscription.shouldTakePriorityOver(inactiveLifetime))
    #expect(!inactiveLifetime.shouldTakePriorityOver(activeSubscription))
  }

  @Test("Non-revoked overrides expiry, renewal, and grace period")
  func testNonRevokedOverridesLowerPriorities() {
    let notRevoked = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(3600), // Short expiry
      isLifetime: false,
      willRenew: false,
      state: .subscribed
    )
    let revoked = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(86400 * 365), // Long expiry
      isLifetime: false,
      willRenew: true,
      state: .revoked
    )

    #expect(notRevoked.shouldTakePriorityOver(revoked))
    #expect(!revoked.shouldTakePriorityOver(notRevoked))
  }

  @Test("Later expiry overrides renewal and grace period")
  func testLaterExpiryOverridesLowerPriorities() {
    let laterExpiry = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(7200),
      isLifetime: false,
      willRenew: false,
      state: .inGracePeriod
    )
    let earlierExpiry = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(3600),
      isLifetime: false,
      willRenew: true,
      state: .subscribed
    )

    #expect(laterExpiry.shouldTakePriorityOver(earlierExpiry))
    #expect(!earlierExpiry.shouldTakePriorityOver(laterExpiry))
  }

  @Test("Will renew overrides grace period only")
  func testWillRenewOverridesGracePeriodOnly() {
    let date = Date().addingTimeInterval(3600)
    let willRenew = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      isLifetime: false,
      willRenew: true,
      state: .inGracePeriod
    )
    let wontRenew = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: date,
      isLifetime: false,
      willRenew: false,
      state: .subscribed
    )

    #expect(willRenew.shouldTakePriorityOver(wontRenew))
    #expect(!wontRenew.shouldTakePriorityOver(willRenew))
  }

  @Test("Real-world device vs web scenario")
  func testRealWorldDeviceVsWebScenario() {
    // Device has active monthly subscription expiring soon
    let device = Entitlement(
      id: "premium",
      isActive: true,
      productIds: Set(["monthly"]),
      latestProductId: "monthly",
      startsAt: Date().addingTimeInterval(-86400 * 30),
      expiresAt: Date().addingTimeInterval(3600), // 1 hour
      isLifetime: false,
      willRenew: true,
      state: .subscribed
    )

    // Web has lifetime purchase
    let web = Entitlement(
      id: "premium",
      isActive: true,
      productIds: Set(["lifetime"]),
      latestProductId: "lifetime",
      startsAt: Date().addingTimeInterval(-86400 * 365),
      expiresAt: nil,
      isLifetime: true,
      willRenew: nil,
      state: nil
    )

    #expect(web.shouldTakePriorityOver(device))
    #expect(!device.shouldTakePriorityOver(web))
  }

  @Test("Real-world expired vs grace period scenario")
  func testRealWorldExpiredVsGracePeriodScenario() {
    // Subscription expired but in grace period (payment issue)
    let gracePeriod = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
      isLifetime: false,
      willRenew: true,
      state: .inGracePeriod
    )

    // Subscription that's still fully valid
    let subscribed = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(3600), // Valid for 1 hour
      isLifetime: false,
      willRenew: true,
      state: .subscribed
    )

    // Later expiry should win (still valid vs expired)
    #expect(subscribed.shouldTakePriorityOver(gracePeriod))
    #expect(!gracePeriod.shouldTakePriorityOver(subscribed))
  }

  @Test("Real-world multiple expired subscriptions scenario")
  func testRealWorldMultipleExpiredSubscriptionsScenario() {
    // Old expired subscription
    let oldExpired = Entitlement(
      id: "premium",
      isActive: false,
      expiresAt: Date().addingTimeInterval(-86400 * 365), // 1 year ago
      isLifetime: false,
      willRenew: false,
      state: .expired
    )

    // Recently expired subscription
    let recentExpired = Entitlement(
      id: "premium",
      isActive: false,
      expiresAt: Date().addingTimeInterval(-3600), // 1 hour ago
      isLifetime: false,
      willRenew: false,
      state: .expired
    )

    // Both inactive, so expiry date wins
    #expect(recentExpired.shouldTakePriorityOver(oldExpired))
    #expect(!oldExpired.shouldTakePriorityOver(recentExpired))
  }

  // MARK: - mergePrioritized Tests

  @Test("mergePrioritized selects lifetime over subscription")
  func testMergePrioritizedSelectsLifetime() {
    let lifetime = Entitlement(id: "premium", isActive: true, isLifetime: true)
    let subscription = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(3600),
      isLifetime: false,
      willRenew: true
    )

    let merged = Entitlement.mergePrioritized([lifetime, subscription])

    #expect(merged.count == 1)
    #expect(merged.first?.isLifetime == true)
  }

  @Test("mergePrioritized preserves different entitlement IDs")
  func testMergePrioritizedPreservesDifferentIds() {
    let premium = Entitlement(id: "premium", isActive: true, isLifetime: true)
    let basic = Entitlement(id: "basic", isActive: true, expiresAt: Date().addingTimeInterval(3600))
    let pro = Entitlement(id: "pro", isActive: false)

    let merged = Entitlement.mergePrioritized([premium, basic, pro])

    #expect(merged.count == 3)

    let entitlementIds = Set(merged.map { $0.id })
    #expect(entitlementIds.contains("premium"))
    #expect(entitlementIds.contains("basic"))
    #expect(entitlementIds.contains("pro"))
  }

  @Test("mergePrioritized preserves metadata of winning entitlement and merges productIds")
  func testMergePrioritizedPreservesMetadataAndMergesProductIds() {
    let device = Entitlement(
      id: "premium",
      isActive: true,
      productIds: Set(["monthly_premium"]),
      latestProductId: "monthly_premium",
      startsAt: Date().addingTimeInterval(-86400), // Started 1 day ago
      expiresAt: Date().addingTimeInterval(3600), // Expires in 1 hour
      willRenew: true
    )

    let web = Entitlement(
      id: "premium",
      isActive: true,
      productIds: Set(["lifetime_premium"]),
      latestProductId: "lifetime_premium",
      startsAt: Date().addingTimeInterval(-172800), // Started 2 days ago
      isLifetime: true
    )

    let merged = Entitlement.mergePrioritized([device, web])

    #expect(merged.count == 1)
    let result = merged.first!

    // Lifetime should win (both active, lifetime takes priority)
    #expect(result.isLifetime == true)
    #expect(result.latestProductId == "lifetime_premium")
    #expect(abs(result.startsAt!.timeIntervalSince(Date().addingTimeInterval(-172800))) < 1)

    // ProductIds should be merged from both entitlements
    #expect(result.productIds == Set(["monthly_premium", "lifetime_premium"]))
  }

  @Test("mergePrioritized handles multiple same-ID entitlements")
  func testMergePrioritizedMultipleSameId() {
    let device = Entitlement(
      id: "premium",
      isActive: true,
      expiresAt: Date().addingTimeInterval(1800), // 30 minutes
      willRenew: true
    )

    let webLifetime = Entitlement(id: "premium", isActive: true, isLifetime: true)

    let webExpired = Entitlement(
      id: "premium",
      isActive: false,
      expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
      willRenew: false
    )

    let merged = Entitlement.mergePrioritized([device, webLifetime, webExpired])

    #expect(merged.count == 1)
    let result = merged.first!
    #expect(result.id == "premium")
    #expect(result.isLifetime == true)
    #expect(result.isActive == true)
  }

  @Test("mergePrioritized returns empty set for empty input")
  func testMergePrioritizedEmptyInput() {
    let merged = Entitlement.mergePrioritized([])
    #expect(merged.isEmpty)
  }

  @Test("mergePrioritized returns single entitlement unchanged")
  func testMergePrioritizedSingleEntitlement() {
    let entitlement = Entitlement(
      id: "premium",
      isActive: true,
      productIds: Set(["monthly"]),
      latestProductId: "monthly"
    )

    let merged = Entitlement.mergePrioritized([entitlement])

    #expect(merged.count == 1)
    #expect(merged.first?.id == "premium")
    #expect(merged.first?.latestProductId == "monthly")
  }
}
