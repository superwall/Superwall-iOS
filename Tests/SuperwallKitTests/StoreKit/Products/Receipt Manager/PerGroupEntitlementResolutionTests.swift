//
//  PerGroupEntitlementResolutionTests.swift
//  SuperwallKitTests
//
//  Created by Claude on 03/09/2026.
//

import Testing
import Foundation
import StoreKit
@testable import SuperwallKit

/// Covers entitlements that are granted by more than one independent source —
/// two subscription groups, or a subscription alongside a lifetime purchase.
/// Each source has to resolve on its own: a refund in one group must not cancel
/// out a paid, active subscription in another.
@Suite("Per-group entitlement resolution")
struct PerGroupEntitlementResolutionTests {
  // MARK: - Helpers

  private struct MockTransaction: EntitlementTransaction {
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

  private func makeTransaction(
    productId: String,
    transactionId: String,
    subscriptionGroupId: String?,
    purchaseDate: Date,
    originalPurchaseDate: Date? = nil,
    expirationDate: Date? = nil,
    isRevoked: Bool = false,
    productType: EntitlementTransactionType = .autoRenewable,
    willRenew: Bool = true
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
      renewedAt: nil,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: !isRevoked && (expirationDate ?? .distantPast) > Date(),
      offerType: nil,
      subscriptionGroupId: subscriptionGroupId
    )
  }

  private func makeEntitlement(
    id: String = "premium",
    productIds: Set<String>
  ) -> Entitlement {
    return Entitlement(
      id: id,
      type: .serviceLevel,
      isActive: false,
      productIds: productIds
    )
  }

  private func fixtures(
    for products: Set<String>,
    entitlementId: String = "premium"
  ) -> (raw: [String: Set<Entitlement>], productIds: [String: Set<String>]) {
    let entitlement = makeEntitlement(id: entitlementId, productIds: products)
    var raw: [String: Set<Entitlement>] = [:]
    for product in products {
      raw[product] = Set([entitlement])
    }
    return (raw, [entitlementId: products])
  }

  // MARK: - Grant source partitioning

  @Test("Products in the same subscription group resolve as one source")
  func sameGroupIsOneSource() {
    let baseDate = Date()
    let transactions: [any EntitlementTransaction] = [
      makeTransaction(
        productId: "monthly",
        transactionId: "txn_1",
        subscriptionGroupId: "group_1",
        purchaseDate: baseDate.addingTimeInterval(-7200),
        expirationDate: baseDate.addingTimeInterval(-3600)
      ),
      makeTransaction(
        productId: "yearly",
        transactionId: "txn_2",
        subscriptionGroupId: "group_1",
        purchaseDate: baseDate,
        expirationDate: baseDate.addingTimeInterval(3600)
      )
    ]

    let sources = EntitlementProcessor.grantSources(for: transactions)

    #expect(sources.count == 1)
    #expect(sources.first?.isActive == true)
    // The upgrade replaced the monthly plan, so the source describes the yearly one.
    #expect(sources.first?.latestProductId == "yearly")
    #expect(sources.first?.expiresAt == baseDate.addingTimeInterval(3600))
  }

  @Test("Separate subscription groups resolve as separate sources")
  func separateGroupsAreSeparateSources() {
    let baseDate = Date()
    let transactions: [any EntitlementTransaction] = [
      makeTransaction(
        productId: "monthly",
        transactionId: "txn_1",
        subscriptionGroupId: "group_1",
        purchaseDate: baseDate.addingTimeInterval(-7200),
        expirationDate: baseDate.addingTimeInterval(3600)
      ),
      makeTransaction(
        productId: "yearly",
        transactionId: "txn_2",
        subscriptionGroupId: "group_2",
        purchaseDate: baseDate,
        expirationDate: baseDate.addingTimeInterval(7200)
      )
    ]

    let sources = EntitlementProcessor.grantSources(for: transactions)

    #expect(sources.count == 2)
    #expect(sources.allSatisfy { $0.isActive })
  }

  @Test("Transactions with no subscription group stand alone per product")
  func missingGroupIdFallsBackToProductId() {
    let baseDate = Date()
    let transactions: [any EntitlementTransaction] = [
      makeTransaction(
        productId: "pass_a",
        transactionId: "txn_1",
        subscriptionGroupId: nil,
        purchaseDate: baseDate,
        expirationDate: baseDate.addingTimeInterval(3600),
        productType: .nonRenewable
      ),
      makeTransaction(
        productId: "pass_b",
        transactionId: "txn_2",
        subscriptionGroupId: nil,
        purchaseDate: baseDate,
        expirationDate: baseDate.addingTimeInterval(7200),
        productType: .nonRenewable
      )
    ]

    let sources = EntitlementProcessor.grantSources(for: transactions)

    #expect(sources.count == 2)
  }

  // MARK: - The refund-across-groups scenario

  @Test("A refund in one group leaves the other group's grant intact")
  func refundInOneGroupDoesNotCancelAnother() async {
    let baseDate = Date()

    // Bought first, stalled in billing retry, then refunded. The refund revokes
    // the transaction but leaves its expiry in the future.
    let refunded = makeTransaction(
      productId: "monthly",
      transactionId: "txn_refunded",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-7200),
      expirationDate: baseDate.addingTimeInterval(1800),
      isRevoked: true,
      willRenew: false
    )

    // Bought while the first plan was stuck. Still paid for and active.
    let paid = makeTransaction(
      productId: "yearly",
      transactionId: "txn_paid",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-3600),
      expirationDate: baseDate.addingTimeInterval(86_400)
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [refunded, paid])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(state: .revoked, willRenew: false, offerType: nil),
        "group_2": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: nil)
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [refunded, paid]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["yearly"]?.first
    #expect(entitlement?.isActive == true)
    // The scalars describe the subscription that is actually granting access.
    #expect(entitlement?.latestProductId == "yearly")
    #expect(entitlement?.state == .subscribed)
    #expect(entitlement?.willRenew == true)
    #expect(entitlement?.expiresAt == baseDate.addingTimeInterval(86_400))

    // Both products report the same entitlement.
    #expect(result["monthly"]?.first == entitlement)

    // Each group was resolved on its own rather than one standing in for both.
    #expect(Set(provider.resolvedTransactionIds.all) == Set(["txn_refunded", "txn_paid"]))
  }

  @Test("A refunded group stays harmless even when it holds the newest purchase")
  func refundedGroupWithNewestPurchaseDoesNotCancelAnother() async {
    let baseDate = Date()

    // The yearly plan was bought first...
    let paid = makeTransaction(
      productId: "yearly",
      transactionId: "txn_paid",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-7200),
      expirationDate: baseDate.addingTimeInterval(86_400)
    )

    // ...then the other group recovered from billing retry and renewed *after*
    // it, and only then was refunded. This is the ordering that makes a
    // most-recent-transaction rule pick the revoked group.
    let refunded = makeTransaction(
      productId: "monthly",
      transactionId: "txn_refunded",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-60),
      originalPurchaseDate: baseDate.addingTimeInterval(-100_000),
      expirationDate: baseDate.addingTimeInterval(1800),
      isRevoked: true,
      willRenew: false
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [paid, refunded])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(state: .revoked, willRenew: false, offerType: nil),
        "group_2": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: nil)
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [paid, refunded]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["yearly"]?.first
    #expect(entitlement?.isActive == true)
    #expect(entitlement?.latestProductId == "yearly")
    #expect(entitlement?.state == .subscribed)
    #expect(entitlement?.willRenew == true)
    #expect(entitlement?.expiresAt == baseDate.addingTimeInterval(86_400))
  }

  @Test("A refund across groups is caught without live status, from dates alone")
  func refundAcrossGroupsResolvesFromDatesAlone() {
    let baseDate = Date()

    // The revoked transaction holds the furthest expiry and the newest purchase.
    let refunded = makeTransaction(
      productId: "monthly",
      transactionId: "txn_refunded",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-60),
      expirationDate: baseDate.addingTimeInterval(200_000),
      isRevoked: true,
      willRenew: false
    )
    let paid = makeTransaction(
      productId: "yearly",
      transactionId: "txn_paid",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-7200),
      expirationDate: baseDate.addingTimeInterval(86_400)
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: ["premium": [refunded, paid]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds
    )

    let entitlement = result["yearly"]?.first
    #expect(entitlement?.isActive == true)
    #expect(entitlement?.latestProductId == "yearly")
    // The revoked transaction's expiry must not leak into the entitlement.
    #expect(entitlement?.expiresAt == baseDate.addingTimeInterval(86_400))
  }

  @Test("Every group revoked leaves the entitlement inactive")
  func allGroupsRevokedIsInactive() async {
    let baseDate = Date()
    let first = makeTransaction(
      productId: "monthly",
      transactionId: "txn_1",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-7200),
      expirationDate: baseDate.addingTimeInterval(1800),
      isRevoked: true,
      willRenew: false
    )
    let second = makeTransaction(
      productId: "yearly",
      transactionId: "txn_2",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-3600),
      expirationDate: baseDate.addingTimeInterval(86_400),
      isRevoked: true,
      willRenew: false
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [first, second])

    let provider = MockSubscriptionStatusProvider(
      mockWillAutoRenew: false,
      mockState: .revoked
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [first, second]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["yearly"]?.first
    #expect(entitlement?.isActive == false)
    #expect(entitlement?.state == .revoked)
    // With nothing granting access, the scalars fall back to the most recent
    // purchase so the entitlement still reports its last known state.
    #expect(entitlement?.latestProductId == "yearly")
  }

  @Test("A revoked subscription cannot cancel a lifetime purchase")
  func lifetimeSurvivesRevokedSubscription() async {
    let baseDate = Date()
    let lifetime = makeTransaction(
      productId: "lifetime",
      transactionId: "txn_lifetime",
      subscriptionGroupId: nil,
      purchaseDate: baseDate.addingTimeInterval(-100_000),
      productType: .nonConsumable,
      willRenew: false
    )
    let refunded = makeTransaction(
      productId: "monthly",
      transactionId: "txn_refunded",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-60),
      expirationDate: baseDate.addingTimeInterval(1800),
      isRevoked: true,
      willRenew: false
    )

    let (raw, productIds) = fixtures(for: ["lifetime", "monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [lifetime, refunded])

    let provider = MockSubscriptionStatusProvider(
      mockWillAutoRenew: false,
      mockState: .revoked
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [lifetime, refunded]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["lifetime"]?.first
    #expect(entitlement?.isActive == true)
    #expect(entitlement?.isLifetime == true)
    #expect(entitlement?.latestProductId == "lifetime")
    // A lifetime purchase has no subscription group, so its status is never
    // queried and the revoked group's state must not be stamped onto it.
    #expect(entitlement?.state == nil)
    #expect(provider.resolvedTransactionIds.all == ["txn_refunded"])
  }

  // MARK: - Grace period

  @Test("A lapsed subscription in its grace period is still active")
  func gracePeriodIsActive() async {
    let baseDate = Date()

    // In a grace period the expiry has already passed — only the live status
    // says the person still has access.
    let lapsed = makeTransaction(
      productId: "monthly",
      transactionId: "txn_grace",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(-60)
    )

    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [lapsed])

    let provider = MockSubscriptionStatusProvider(
      mockWillAutoRenew: true,
      mockState: .inGracePeriod
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [lapsed]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["monthly"]?.first
    #expect(entitlement?.isActive == true)
    #expect(entitlement?.state == .inGracePeriod)
    #expect(subscriptions.first?.isInGracePeriod == true)
  }

  @Test("A grace period in one group keeps the entitlement active on its own")
  func gracePeriodGrantsAlongsideAnExpiredGroup() async {
    let baseDate = Date()
    let expired = makeTransaction(
      productId: "yearly",
      transactionId: "txn_expired",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-100_000),
      expirationDate: baseDate.addingTimeInterval(-1000),
      willRenew: false
    )
    let inGrace = makeTransaction(
      productId: "monthly",
      transactionId: "txn_grace",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(-60)
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [expired, inGrace])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(state: .inGracePeriod, willRenew: true, offerType: nil),
        "group_2": ResolvedSubscriptionStatus(state: .expired, willRenew: false, offerType: nil)
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [expired, inGrace]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["monthly"]?.first
    #expect(entitlement?.isActive == true)
    #expect(entitlement?.state == .inGracePeriod)
    #expect(entitlement?.latestProductId == "monthly")
  }

  @Test("An expired group cannot cancel a subscribed group")
  func expiredGroupDoesNotCancelSubscribedGroup() async {
    let baseDate = Date()
    let expired = makeTransaction(
      productId: "monthly",
      transactionId: "txn_expired",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-60),
      expirationDate: baseDate.addingTimeInterval(3600),
      willRenew: false
    )
    let subscribed = makeTransaction(
      productId: "yearly",
      transactionId: "txn_subscribed",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-7200),
      expirationDate: baseDate.addingTimeInterval(86_400)
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [expired, subscribed])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        // StoreKit says this group has lapsed even though the transaction's own
        // expiry is still in the future.
        "group_1": ResolvedSubscriptionStatus(state: .expired, willRenew: false, offerType: nil),
        "group_2": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: nil)
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [expired, subscribed]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["yearly"]?.first
    #expect(entitlement?.isActive == true)
    #expect(entitlement?.state == .subscribed)
    #expect(entitlement?.latestProductId == "yearly")
    #expect(entitlement?.expiresAt == baseDate.addingTimeInterval(86_400))
  }

  // MARK: - Billing retry

  @Test("Billing retry leaves the dates in charge")
  func billingRetryDefersToDates() async {
    let baseDate = Date()
    let stillPaidFor = makeTransaction(
      productId: "monthly",
      transactionId: "txn_paid_for",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(3600)
    )
    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [stillPaidFor])

    let provider = MockSubscriptionStatusProvider(
      mockWillAutoRenew: true,
      mockState: .inBillingRetryPeriod
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [stillPaidFor]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    // The paid-for period has not run out yet, so access continues.
    #expect(result["monthly"]?.first?.isActive == true)
    #expect(result["monthly"]?.first?.state == .inBillingRetryPeriod)
    #expect(subscriptions.first?.isInBillingRetryPeriod == true)
  }

  @Test("Billing retry past the expiry date is inactive")
  func billingRetryPastExpiryIsInactive() async {
    let baseDate = Date()
    let lapsed = makeTransaction(
      productId: "monthly",
      transactionId: "txn_lapsed",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(-60)
    )
    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [lapsed])

    let provider = MockSubscriptionStatusProvider(
      mockWillAutoRenew: true,
      mockState: .inBillingRetryPeriod
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [lapsed]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    #expect(result["monthly"]?.first?.isActive == false)
  }

  // MARK: - Status lookups

  @Test("Each subscription group costs one status lookup")
  func statusIsResolvedOncePerGroup() async {
    let baseDate = Date()
    let older = makeTransaction(
      productId: "monthly",
      transactionId: "txn_1",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-100_000),
      expirationDate: baseDate.addingTimeInterval(-90_000)
    )
    let newer = makeTransaction(
      productId: "monthly",
      transactionId: "txn_2",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-3600),
      expirationDate: baseDate.addingTimeInterval(3600)
    )

    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [older, newer])
    let provider = MockSubscriptionStatusProvider()

    _ = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [older, newer]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    // One group, one lookup — against its newest transaction.
    #expect(provider.resolvedTransactionIds.all == ["txn_2"])
  }

  @Test("Entitlements sharing a subscription group share its status lookup")
  func statusLookupIsSharedAcrossEntitlements() async {
    let baseDate = Date()
    let transaction = makeTransaction(
      productId: "monthly",
      transactionId: "txn_1",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-3600),
      expirationDate: baseDate.addingTimeInterval(3600)
    )

    let premium = makeEntitlement(id: "premium", productIds: ["monthly"])
    let proTools = makeEntitlement(id: "pro_tools", productIds: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [transaction])
    let provider = MockSubscriptionStatusProvider()

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [transaction], "pro_tools": [transaction]],
      rawEntitlementsByProductId: ["monthly": Set([premium, proTools])],
      productIdsByEntitlementId: ["premium": ["monthly"], "pro_tools": ["monthly"]],
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    #expect(result["monthly"]?.count == 2)
    #expect(result["monthly"]?.allSatisfy { $0.isActive } == true)
    #expect(provider.resolvedTransactionIds.all == ["txn_1"])
  }

  @Test("An unavailable status leaves the date-based resolution alone")
  func missingStatusFallsBackToDates() async {
    let baseDate = Date()
    let active = makeTransaction(
      productId: "monthly",
      transactionId: "txn_1",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-3600),
      expirationDate: baseDate.addingTimeInterval(3600)
    )

    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [active])
    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [:],
      defaultStatus: nil
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [active]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    #expect(result["monthly"]?.first?.isActive == true)
    #expect(result["monthly"]?.first?.state == nil)
  }

  // MARK: - Latest subscription device variables

  @Test("The latest subscription is the most recently bought one, not the longest one")
  func latestSubscriptionFollowsPurchaseRecency() async {
    let baseDate = Date()
    // Bought a year ago, but it runs the furthest into the future.
    let oldYearly = makeTransaction(
      productId: "yearly",
      transactionId: "txn_yearly",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-31_536_000),
      expirationDate: baseDate.addingTimeInterval(86_400),
      willRenew: false
    )
    // Bought yesterday, so this is the latest subscription.
    let newMonthly = makeTransaction(
      productId: "monthly",
      transactionId: "txn_monthly",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(3600)
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [oldYearly, newMonthly])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(state: .expired, willRenew: false, offerType: .promotional),
        "group_2": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: .trial)
      ]
    )

    var capturedState: LatestSubscription.State?
    var capturedWillRenew: Bool?
    var capturedOfferType: LatestSubscription.OfferType?

    _ = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [oldYearly, newMonthly]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    ) { state, willRenew, offerType in
      capturedState = state
      capturedWillRenew = willRenew
      capturedOfferType = offerType
    }

    #expect(capturedState == .subscribed)
    #expect(capturedWillRenew == true)
    #expect(capturedOfferType == .trial)
  }

  @Test("The latest subscription is picked across entitlements, not by iteration order")
  func latestSubscriptionIsPickedAcrossEntitlements() async {
    let baseDate = Date()
    let older = makeTransaction(
      productId: "pro_monthly",
      transactionId: "txn_pro",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(3600)
    )
    let newer = makeTransaction(
      productId: "plus_monthly",
      transactionId: "txn_plus",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-60),
      expirationDate: baseDate.addingTimeInterval(3600)
    )

    let pro = makeEntitlement(id: "pro", productIds: ["pro_monthly"])
    let plus = makeEntitlement(id: "plus", productIds: ["plus_monthly"])
    let raw: [String: Set<Entitlement>] = ["pro_monthly": [pro], "plus_monthly": [plus]]
    let productIds: [String: Set<String>] = ["pro": ["pro_monthly"], "plus": ["plus_monthly"]]

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(state: .inBillingRetryPeriod, willRenew: false, offerType: .code),
        "group_2": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: .winback)
      ]
    )

    // Run it repeatedly: the two entitlements come out of a dictionary, so a
    // last-one-wins pick would only sometimes land on the wrong one.
    for _ in 0..<10 {
      var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [older, newer])
      var capturedState: LatestSubscription.State?
      var capturedOfferType: LatestSubscription.OfferType?

      _ = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
        from: ["pro": [older], "plus": [newer]],
        rawEntitlementsByProductId: raw,
        productIdsByEntitlementId: productIds,
        subscriptions: &subscriptions,
        subscriptionStatusProvider: provider
      ) { state, _, offerType in
        capturedState = state
        capturedOfferType = offerType
      }

      #expect(capturedState == .subscribed)
      #expect(capturedOfferType == .winback)
    }
  }

  @Test("A lifetime purchase is never reported as the latest subscription")
  func lifetimeIsNotTheLatestSubscription() async {
    let baseDate = Date()
    let subscription = makeTransaction(
      productId: "monthly",
      transactionId: "txn_monthly",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(3600)
    )
    let lifetime = makeTransaction(
      productId: "lifetime",
      transactionId: "txn_lifetime",
      subscriptionGroupId: nil,
      purchaseDate: baseDate,
      productType: .nonConsumable,
      willRenew: false
    )

    let (raw, productIds) = fixtures(for: ["monthly", "lifetime"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [subscription, lifetime])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: .trial)
      ]
    )

    var captured: LatestSubscription.State?
    var callCount = 0

    _ = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [subscription, lifetime]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    ) { state, _, _ in
      captured = state
      callCount += 1
    }

    #expect(callCount == 1)
    #expect(captured == .subscribed)
  }

  // MARK: - Revoked sources

  @Test("A subscribed group cannot resurrect a fully revoked source")
  func subscribedDoesNotResurrectRevokedSource() async {
    let baseDate = Date()
    let revoked = makeTransaction(
      productId: "monthly",
      transactionId: "txn_revoked",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(86_400),
      isRevoked: true
    )
    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [revoked])

    // A refunded Family Sharing member alongside a group that still reports as
    // subscribed for its owner.
    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: nil)
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [revoked]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    #expect(result["monthly"]?.first?.isActive == false)
  }

  @Test("A revoked group cannot outrank the group actually paying")
  func revokedSourceDoesNotDescribeTheEntitlement() async {
    let baseDate = Date()
    let revoked = makeTransaction(
      productId: "monthly",
      transactionId: "txn_revoked",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate,
      expirationDate: baseDate.addingTimeInterval(86_400),
      isRevoked: true
    )
    let paying = makeTransaction(
      productId: "yearly",
      transactionId: "txn_paying",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-7200),
      expirationDate: baseDate.addingTimeInterval(3600)
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [revoked, paying])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: nil),
        "group_2": ResolvedSubscriptionStatus(state: .subscribed, willRenew: true, offerType: nil)
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [revoked, paying]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["yearly"]?.first
    #expect(entitlement?.isActive == true)
    #expect(entitlement?.latestProductId == "yearly")
    #expect(entitlement?.expiresAt == baseDate.addingTimeInterval(3600))
  }

  // MARK: - Expiry date of an active entitlement

  @Test("A grace period moves the expiry date to the end of the grace period")
  func gracePeriodCarriesItsOwnExpiry() async {
    let baseDate = Date()
    let gracePeriodEnd = baseDate.addingTimeInterval(1_209_600)
    let lapsed = makeTransaction(
      productId: "monthly",
      transactionId: "txn_lapsed",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-2_678_400),
      expirationDate: baseDate.addingTimeInterval(-60)
    )
    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [lapsed])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(
          state: .inGracePeriod,
          willRenew: true,
          offerType: nil,
          activeUntil: gracePeriodEnd
        )
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [lapsed]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    let entitlement = result["monthly"]?.first
    #expect(entitlement?.isActive == true)
    // An active entitlement whose expiry has already passed reads as inactive to
    // every "good until" check downstream, so the two have to move together.
    #expect(entitlement?.expiresAt == gracePeriodEnd)
    #expect(entitlement?.renewsAt == gracePeriodEnd)
  }

  @Test("A renewal StoreKit knows about beats the stale transaction expiry")
  func subscribedCarriesTheRenewalDate() async {
    let baseDate = Date()
    let renewalDate = baseDate.addingTimeInterval(2_678_400)
    let stale = makeTransaction(
      productId: "monthly",
      transactionId: "txn_stale",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-2_678_400),
      expirationDate: baseDate.addingTimeInterval(-60)
    )
    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [stale])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(
          state: .subscribed,
          willRenew: true,
          offerType: nil,
          activeUntil: renewalDate
        )
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [stale]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    #expect(result["monthly"]?.first?.isActive == true)
    #expect(result["monthly"]?.first?.expiresAt == renewalDate)
  }

  @Test("A live status never pulls the expiry date backwards")
  func liveStatusNeverShortensTheExpiry() async {
    let baseDate = Date()
    let paidFor = makeTransaction(
      productId: "monthly",
      transactionId: "txn_paid_for",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-60),
      expirationDate: baseDate.addingTimeInterval(86_400)
    )
    let (raw, productIds) = fixtures(for: ["monthly"])
    var (_, subscriptions) = EntitlementProcessor.processTransactions(from: [paidFor])

    let provider = MockSubscriptionStatusProvider(
      statusesByGroupId: [
        "group_1": ResolvedSubscriptionStatus(
          state: .subscribed,
          willRenew: true,
          offerType: nil,
          activeUntil: baseDate.addingTimeInterval(3600)
        )
      ]
    )

    let result = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: ["premium": [paidFor]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: provider
    )

    #expect(result["monthly"]?.first?.expiresAt == baseDate.addingTimeInterval(86_400))
  }

  // MARK: - Scalar fields

  @Test("Renewals are dated from the group granting the entitlement")
  func renewedAtComesFromTheGrantingGroup() {
    let baseDate = Date()
    let renewal = makeTransaction(
      productId: "yearly",
      transactionId: "txn_renewal",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-3600),
      originalPurchaseDate: baseDate.addingTimeInterval(-31_536_000),
      expirationDate: baseDate.addingTimeInterval(31_536_000)
    )
    let otherGroup = makeTransaction(
      productId: "monthly",
      transactionId: "txn_monthly",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-600),
      originalPurchaseDate: baseDate.addingTimeInterval(-2_678_400),
      expirationDate: baseDate.addingTimeInterval(3600)
    )

    let (raw, productIds) = fixtures(for: ["monthly", "yearly"])

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: ["premium": [renewal, otherGroup]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds
    )

    let entitlement = result["yearly"]?.first
    // The yearly has the most time left on it, so it describes the entitlement.
    #expect(entitlement?.latestProductId == "yearly")
    #expect(entitlement?.renewedAt == baseDate.addingTimeInterval(-3600))
    // The entitlement started with the earliest purchase that unlocked it.
    #expect(entitlement?.startsAt == baseDate.addingTimeInterval(-31_536_000))
  }

  @Test("A refund and a consumable never date the start of an entitlement")
  func startsAtIgnoresRefundsAndConsumables() {
    let baseDate = Date()
    let refunded = makeTransaction(
      productId: "monthly",
      transactionId: "txn_refunded",
      subscriptionGroupId: "group_1",
      purchaseDate: baseDate.addingTimeInterval(-31_536_000),
      expirationDate: baseDate.addingTimeInterval(-30_000_000),
      isRevoked: true
    )
    let consumable = makeTransaction(
      productId: "coins",
      transactionId: "txn_coins",
      subscriptionGroupId: nil,
      purchaseDate: baseDate.addingTimeInterval(-20_000_000),
      productType: .consumable,
      willRenew: false
    )
    let paying = makeTransaction(
      productId: "yearly",
      transactionId: "txn_paying",
      subscriptionGroupId: "group_2",
      purchaseDate: baseDate.addingTimeInterval(-86_400),
      expirationDate: baseDate.addingTimeInterval(86_400)
    )

    let (raw, productIds) = fixtures(for: ["monthly", "coins", "yearly"])

    let result = EntitlementProcessor.buildEntitlementsFromTransactions(
      from: ["premium": [refunded, consumable, paying]],
      rawEntitlementsByProductId: raw,
      productIdsByEntitlementId: productIds
    )

    #expect(result["yearly"]?.first?.startsAt == baseDate.addingTimeInterval(-86_400))
  }
}
