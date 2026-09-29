//
//  EntitlementProcessor.swift
//  SuperwallKit
//
//  Created by Claude on 11/09/2025.
//
// swiftlint:disable all

import Foundation
import StoreKit

/// The latest subscription on device.
public enum LatestSubscription: Sendable {
  /// The offer type for the subscription.
  public enum OfferType: String, Sendable, Codable {
    case trial
    case code
    case promotional
    case winback
  }
  public typealias PeriodType = OfferType

  /// The state of the subscription.
  public enum State: String, Sendable, Codable {
    case inGracePeriod
    case subscribed
    case expired
    case inBillingRetryPeriod
    case revoked
  }
}

/// Protocol to abstract over different transaction types for entitlement processing
protocol EntitlementTransaction {
  var productId: String { get }
  var transactionId: String { get }
  var purchaseDate: Date { get }
  var originalPurchaseDate: Date { get }
  var expirationDate: Date? { get }
  var isRevoked: Bool { get }
  var entitlementProductType: EntitlementTransactionType { get }
  var willRenew: Bool { get }
  var renewedAt: Date? { get }
  var isInGracePeriod: Bool { get }
  var isInBillingRetryPeriod: Bool { get }
  var isActive: Bool { get }
  var offerType: LatestSubscription.OfferType? { get }
  var subscriptionGroupId: String? { get }
}

/// Common product types for entitlement processing
enum EntitlementTransactionType {
  case consumable
  case nonConsumable
  case autoRenewable
  case nonRenewable
}

/// The live subscription status of a single grant source, as reported by StoreKit.
struct ResolvedSubscriptionStatus: Sendable {
  let state: LatestSubscription.State?
  let willRenew: Bool
  let offerType: LatestSubscription.OfferType?

  /// The date the group's access actually runs to, when StoreKit knows it and the
  /// transaction dates don't: the end of a billing grace period, or the next
  /// renewal date of a subscription whose latest renewal hasn't reached
  /// `Transaction.all` yet. `nil` when StoreKit doesn't report one.
  let activeUntil: Date?

  init(
    state: LatestSubscription.State?,
    willRenew: Bool,
    offerType: LatestSubscription.OfferType?,
    activeUntil: Date? = nil
  ) {
    self.state = state
    self.willRenew = willRenew
    self.offerType = offerType
    self.activeUntil = activeUntil
  }
}

/// Protocol for providing subscription status information.
///
/// Keyed on ``EntitlementTransaction`` rather than `StoreKit.Transaction` so the
/// resolution logic can be exercised without minting real StoreKit transactions.
@available(iOS 15.0, *)
protocol SubscriptionStatusProvider {
  /// Resolves the live subscription status for the subscription group that
  /// `transaction` belongs to, or `nil` when StoreKit has nothing to say about it.
  func resolveStatus(for transaction: any EntitlementTransaction) async -> ResolvedSubscriptionStatus?
}

/// Default implementation using StoreKit directly
@available(iOS 15.0, *)
struct StoreKitSubscriptionStatusProvider: SubscriptionStatusProvider {
  func resolveStatus(for transaction: any EntitlementTransaction) async -> ResolvedSubscriptionStatus? {
    guard let transaction = transaction as? Transaction else {
      return nil
    }
    let status = await transaction.subscriptionStatus

    var offerType: LatestSubscription.OfferType?
    if #available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *) {
      offerType = getOfferType(from: transaction)
    }

    return ResolvedSubscriptionStatus(
      state: getSubscriptionState(from: status),
      willRenew: getWillAutoRenew(from: status),
      offerType: offerType,
      activeUntil: getActiveUntil(from: status)
    )
  }

  /// The date StoreKit says the subscription's access runs to.
  ///
  /// In a grace period that's the end of the grace period; otherwise it's the next
  /// renewal date, which covers a renewal Apple has taken but `Transaction.all`
  /// hasn't caught up on. The renewal date only exists in the iOS 17 SDK, so
  /// older toolchains fall back to the grace period alone.
  func getActiveUntil(from status: StoreKit.Product.SubscriptionInfo.Status?) -> Date? {
    guard case let .verified(info) = status?.renewalInfo else {
      return nil
    }
    if let gracePeriodExpirationDate = info.gracePeriodExpirationDate {
      return gracePeriodExpirationDate
    }
    #if compiler(>=5.9)
    return info.renewalDate
    #else
    return nil
    #endif
  }

  func getWillAutoRenew(from status: StoreKit.Product.SubscriptionInfo.Status?) -> Bool {
    if case let .verified(info) = status?.renewalInfo {
      return info.willAutoRenew
    }
    return false
  }

  func getSubscriptionState(from status: StoreKit.Product.SubscriptionInfo.Status?) -> LatestSubscription.State? {
    switch status?.state {
    case .inGracePeriod:
      return .inGracePeriod
    case .subscribed:
      return .subscribed
    case .expired:
      return .expired
    case .inBillingRetryPeriod:
      return .inBillingRetryPeriod
    case .revoked:
      return .revoked
    default:
      return nil
    }
  }

  @available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *)
  func getOfferType(from transaction: Transaction) -> LatestSubscription.OfferType? {
    #if compiler(>=6.0.0)
    if transaction.offer?.type == .winBack {
      return .winback
    }
    #endif
    guard let offer = transaction.offer else {
      return nil
    }
    switch offer.type {
    case .introductory:
      return .trial
    case .code:
      return .code
    case .promotional:
      return .promotional
    default:
      return nil
    }
  }
}

/// Utility for processing entitlements from transaction data
enum EntitlementProcessor {
  /// Process transactions into subscription and non-subscription transaction objects
  static func processTransactions(
    from transactions: [any EntitlementTransaction]
  ) -> (nonSubscriptions: [NonSubscriptionTransaction], subscriptions: [SubscriptionTransaction]) {
    var nonSubscriptions: [NonSubscriptionTransaction] = []
    var subscriptions: [SubscriptionTransaction] = []

    for transaction in transactions {
      switch transaction.entitlementProductType {
      case .consumable,
        .nonConsumable:
        nonSubscriptions.append(
          NonSubscriptionTransaction(
            transactionId: transaction.transactionId,
            productId: transaction.productId,
            purchaseDate: transaction.purchaseDate,
            isConsumable: transaction.entitlementProductType == .consumable,
            isRevoked: transaction.isRevoked,
            store: .appStore
          )
        )
      case .autoRenewable,
        .nonRenewable:
        subscriptions.append(
          SubscriptionTransaction(
            transactionId: transaction.transactionId,
            productId: transaction.productId,
            purchaseDate: transaction.purchaseDate,
            willRenew: transaction.willRenew,
            isRevoked: transaction.isRevoked,
            isInGracePeriod: transaction.isInGracePeriod,
            isInBillingRetryPeriod: transaction.isInBillingRetryPeriod,
            isActive: transaction.isActive,
            expirationDate: transaction.expirationDate,
            offerType: transaction.offerType,
            subscriptionGroupId: transaction.subscriptionGroupId,
            store: .appStore
          )
        )
      }
    }

    return (nonSubscriptions, subscriptions)
  }

  // MARK: - Grant Sources

  /// One independent source of a grant for a single entitlement.
  ///
  /// Transactions within an App Store subscription group are mutually exclusive —
  /// at most one is live at a time — but separate groups are independent of one
  /// another, as is a lifetime purchase. Each source is therefore resolved on its
  /// own and the entitlement is active if *any* source grants it. Resolving the
  /// entitlement from a single most-recently-purchased transaction instead lets a
  /// refund in one group cancel out a paid, active subscription in another.
  struct GrantSource {
    /// The newest transaction in this source that hasn't been refunded, if any.
    let unrevokedRepresentative: (any EntitlementTransaction)?

    /// The newest transaction in this source, refunded or not.
    let lastKnownRepresentative: any EntitlementTransaction

    /// Every product bought in this source, refunded or not.
    let productIds: Set<String>
    let isLifetime: Bool
    var isActive: Bool
    var expiresAt: Date?
    var renewedAt: Date?
    var willRenew: Bool
    var state: LatestSubscription.State?
    var offerType: LatestSubscription.OfferType?

    /// Whether any transaction in this source is still unrevoked. A source whose
    /// every transaction has been revoked grants nothing, whatever the
    /// group-level status says.
    var hasUnrevokedTransaction: Bool { unrevokedRepresentative != nil }

    /// The transaction that describes this source.
    ///
    /// While the source is granting access only a purchase that still counts may
    /// describe it, or a refund would name the product unlocking the
    /// entitlement. Once it grants nothing there is no such claim to protect, so
    /// the most recent purchase describes it whether or not it was refunded —
    /// which is what lets a refund be told apart from a plain lapse.
    ///
    /// This reads off `isActive` rather than being fixed when the source is
    /// built, because the live subscription status can promote a source that the
    /// transaction dates alone called lapsed.
    var representative: any EntitlementTransaction {
      if isActive,
        let unrevokedRepresentative = unrevokedRepresentative {
        return unrevokedRepresentative
      }
      return lastKnownRepresentative
    }

    /// The transaction whose subscription group is queried for live status.
    ///
    /// Prefers one that still counts, since that names the subscription the
    /// customer actually holds. Unlike ``representative`` it never moves, so the
    /// status lookup can't depend on a value that lookup goes on to change.
    var statusTransaction: any EntitlementTransaction {
      return unrevokedRepresentative ?? lastKnownRepresentative
    }

    var latestProductId: String { representative.productId }
    var latestPurchaseDate: Date { representative.purchaseDate }
  }

  /// Splits an entitlement's transactions into independent grant sources,
  /// resolving each one from the transaction dates alone.
  static func grantSources(
    for transactions: [any EntitlementTransaction]
  ) -> [GrantSource] {
    let now = Date()
    let lifetimeKey = "lifetime"
    var bucketKeys: [String] = []
    var buckets: [String: [any EntitlementTransaction]] = [:]

    for transaction in transactions {
      let key: String

      switch transaction.entitlementProductType {
      case .nonConsumable:
        // A revoked lifetime purchase grants nothing.
        if transaction.isRevoked {
          continue
        }
        key = lifetimeKey
      case .autoRenewable,
        .nonRenewable:
        // Products in the same subscription group replace one another, so they
        // resolve together. Anything without a group — non-renewing
        // subscriptions, StoreKit 1 — stands alone under its product ID.
        key = transaction.subscriptionGroupId.map { "group:\($0)" } ?? "product:\(transaction.productId)"
      case .consumable:
        // Consumables never grant an entitlement.
        continue
      }

      if buckets[key] == nil {
        bucketKeys.append(key)
      }
      buckets[key, default: []].append(transaction)
    }

    return bucketKeys.compactMap { key -> GrantSource? in
      guard let bucket = buckets[key] else {
        return nil
      }
      let isLifetime = key == lifetimeKey
      let unrevoked = bucket.filter { !$0.isRevoked }
      guard let lastKnownRepresentative = bucket
        .max(by: { $0.purchaseDate < $1.purchaseDate }) else {
        return nil
      }

      var source = GrantSource(
        unrevokedRepresentative: unrevoked.max(by: { $0.purchaseDate < $1.purchaseDate }),
        lastKnownRepresentative: lastKnownRepresentative,
        productIds: Set(bucket.map(\.productId)),
        isLifetime: isLifetime,
        // A lifetime purchase never expires. Everything else grants access for
        // as long as an unrevoked transaction still has time left on it.
        isActive: isLifetime || unrevoked.contains { ($0.expirationDate ?? .distantPast) > now },
        expiresAt: isLifetime ? nil : unrevoked.compactMap(\.expirationDate).max(),
        renewedAt: unrevoked
          .filter { $0.entitlementProductType == .autoRenewable && $0.originalPurchaseDate < $0.purchaseDate }
          .map(\.purchaseDate)
          .max(),
        willRenew: false,
        state: nil,
        offerType: nil
      )
      source.willRenew = source.representative.willRenew
      return source
    }
  }

  /// Picks the source that describes the entitlement's scalar fields.
  ///
  /// Prefers whatever is actually granting access — a lifetime purchase, then the
  /// active source with the most time left on it — so `state`, `willRenew`,
  /// `expiresAt` and `latestProductId` all describe the same subscription. Only
  /// when nothing is active does it fall back to the most recent purchase, so a
  /// lapsed entitlement still reports its last known state.
  static func representativeSource(from sources: [GrantSource]) -> GrantSource? {
    if let lifetime = sources.first(where: { $0.isLifetime && $0.isActive }) {
      return lifetime
    }

    let activeSources = sources.filter { $0.isActive }

    if activeSources.isEmpty {
      return sources.max { $0.latestPurchaseDate < $1.latestPurchaseDate }
    }

    return activeSources.max {
      ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture)
    }
  }

  /// Picks the source describing the most recently bought subscription.
  ///
  /// The `latestSubscription` device variables are about recency, not about which
  /// source is granting access, so this deliberately differs from
  /// ``representativeSource(from:)``: a yearly bought last year has more time left
  /// on it than a monthly bought yesterday, but the monthly is the latest one.
  static func latestSubscriptionSource(from sources: [GrantSource]) -> GrantSource? {
    return sources
      .filter { !$0.isLifetime }
      .max { $0.latestPurchaseDate < $1.latestPurchaseDate }
  }

  /// Process entitlements from transactions, enriching them with metadata
  static func buildEntitlementsFromTransactions(
    from transactionsByEntitlement: [String: [any EntitlementTransaction]],
    rawEntitlementsByProductId: [String: Set<Entitlement>],
    productIdsByEntitlementId: [String: Set<String>]
  ) -> [String: Set<Entitlement>] {
    let sourcesByEntitlement = transactionsByEntitlement.mapValues { grantSources(for: $0) }

    return buildEntitlements(
      from: transactionsByEntitlement,
      sourcesByEntitlement: sourcesByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )
  }

  /// Enriches the raw entitlements using already-resolved grant sources.
  private static func buildEntitlements(
    from transactionsByEntitlement: [String: [any EntitlementTransaction]],
    sourcesByEntitlement: [String: [GrantSource]],
    rawEntitlementsByProductId: [String: Set<Entitlement>],
    productIdsByEntitlementId: [String: Set<String>]
  ) -> [String: Set<Entitlement>] {
    var processedEntitlementsByProductId: [String: Set<Entitlement>] = [:]

    for (entitlementId, transactions) in transactionsByEntitlement {
      let sources = sourcesByEntitlement[entitlementId] ?? []

      // One source's refund or expiry can never cancel another's grant, so the
      // entitlement is active if any source grants it.
      let isActive = sources.contains { $0.isActive }
      let grantingSource = representativeSource(from: sources)

      // Unlike `state` and `willRenew`, this isn't a property of the current
      // subscription period, so it takes the latest renewal from any source. A
      // group that renewed last week has renewed whether or not it's the one
      // describing the entitlement today.
      let renewedAt = sources.compactMap(\.renewedAt).max()
      // Only transactions that could unlock the entitlement date its start — a
      // refunded purchase or a consumable never did.
      let startsAt = transactions
        .filter { !$0.isRevoked && $0.entitlementProductType != .consumable }
        .map(\.originalPurchaseDate)
        .min()

      // Find all product IDs for this entitlement from server config
      let productIds = productIdsByEntitlementId[entitlementId] ?? []

      for productId in productIds {
        // Get the raw entitlement info for this product
        guard let rawEntitlements = rawEntitlementsByProductId[productId] else {
          continue
        }
        var enrichedEntitlements: Set<Entitlement> = []

        for rawEntitlement in rawEntitlements where rawEntitlement.id == entitlementId {
          let enrichedEntitlement = Entitlement(
            id: rawEntitlement.id,
            type: rawEntitlement.type,
            isActive: isActive,
            productIds: productIds,
            latestProductId: grantingSource?.latestProductId,
            store: .appStore,
            startsAt: startsAt,
            renewedAt: renewedAt,
            expiresAt: grantingSource?.expiresAt,
            isLifetime: grantingSource?.isLifetime ?? false,
            willRenew: grantingSource?.willRenew ?? false,
            state: grantingSource?.state,
            offerType: grantingSource?.offerType
          )
          enrichedEntitlements.insert(enrichedEntitlement)
        }

        processedEntitlementsByProductId[productId, default: []].formUnion(enrichedEntitlements)
      }
    }

    // Add entitlements from config that have no transactions
    // This ensures all entitlements are available even if never purchased
    let processedEntitlementIds = Set(transactionsByEntitlement.keys)
    for (productId, rawEntitlements) in rawEntitlementsByProductId {
      for rawEntitlement in rawEntitlements {
        // If this entitlement wasn't processed (no transactions for this entitlement ID),
        // add it as inactive to preserve the full entitlement structure
        if !processedEntitlementIds.contains(rawEntitlement.id) {
          processedEntitlementsByProductId[productId, default: []].insert(rawEntitlement)
        }
      }
    }

    return processedEntitlementsByProductId
  }

  /// Build entitlements with live subscription data from StoreKit
  @available(iOS 15.0, *)
  static func buildEntitlementsWithLiveSubscriptionData(
    from transactionsByEntitlement: [String: [any EntitlementTransaction]],
    rawEntitlementsByProductId: [String: Set<Entitlement>],
    productIdsByEntitlementId: [String: Set<String>],
    subscriptions: inout [SubscriptionTransaction],
    subscriptionStatusProvider: SubscriptionStatusProvider,
    enableExperimentalDeviceVariables: Bool = false,
    onLatestSubscriptionUpdate: ((LatestSubscription.State?, Bool?, LatestSubscription.OfferType?) -> Void)? = nil,
    onGrantingProductIds: ((Set<String>) -> Void)? = nil,
    onLapsedProductIds: ((Set<String>) -> Void)? = nil
  ) async -> [String: Set<Entitlement>] {
    var sourcesByEntitlement: [String: [GrantSource]] = [:]
    var grantingProductIds: Set<String> = []
    var lapsedProductIds: Set<String> = []
    var updatedSubscriptions = subscriptions
    var latestSubscription: GrantSource?

    // The same subscription group can back several entitlements. Cached by the
    // transaction the group was resolved from, so entitlements sharing that
    // transaction share one lookup. The value is itself optional, so an
    // unwrapped `cached` here is a recorded "StoreKit had nothing to say".
    var statusCache: [String: ResolvedSubscriptionStatus?] = [:]

    for (entitlementId, transactions) in transactionsByEntitlement {
      var sources = grantSources(for: transactions)

      for index in sources.indices {
        // A lifetime purchase has no subscription group to ask about.
        if sources[index].isLifetime {
          continue
        }
        // Never `representative`: this lookup decides `isActive`, which
        // `representative` is derived from.
        let statusTransaction = sources[index].statusTransaction

        let resolvedStatus: ResolvedSubscriptionStatus?
        if let cached = statusCache[statusTransaction.transactionId] {
          resolvedStatus = cached
        } else {
          resolvedStatus = await subscriptionStatusProvider.resolveStatus(for: statusTransaction)
          statusCache[statusTransaction.transactionId] = resolvedStatus
        }

        guard let status = resolvedStatus else {
          continue
        }

        sources[index].willRenew = status.willRenew
        sources[index].state = status.state
        sources[index].offerType = status.offerType

        // The subscription-level state is authoritative for the group it
        // describes — and only for that group. `Transaction.all` can hold a
        // transaction with no revocation date or a future expiry even though the
        // subscription as a whole has been revoked or has lapsed, and it holds
        // nothing at all to show that a lapsed subscription is in its grace
        // period.
        switch status.state {
        case .subscribed,
          .inGracePeriod:
          // A source whose every transaction has been revoked grants nothing.
          // The group status isn't clearly scoped to one Family Sharing member,
          // so it must never resurrect a refunded transaction.
          if sources[index].hasUnrevokedTransaction {
            sources[index].isActive = true

            // Move the expiry date along with the grant. Leaving the lapsed date
            // in place would make the entitlement active and already expired,
            // which every downstream "good until" check reads as inactive.
            if let activeUntil = status.activeUntil,
              activeUntil > (sources[index].expiresAt ?? .distantPast) {
              sources[index].expiresAt = activeUntil
            }
          }
        case .revoked,
          .expired:
          sources[index].isActive = false
        case .inBillingRetryPeriod,
          nil:
          // Billing retry says nothing about whether the paid-for period has run
          // out yet, so the dates stay in charge.
          break
        }

        if let subscriptionIndex = updatedSubscriptions.firstIndex(
          where: { $0.transactionId == statusTransaction.transactionId }
        ) {
          updatedSubscriptions[subscriptionIndex].willRenew = status.willRenew
          updatedSubscriptions[subscriptionIndex].isInGracePeriod = status.state == .inGracePeriod
          updatedSubscriptions[subscriptionIndex].isInBillingRetryPeriod = status.state == .inBillingRetryPeriod
        }
      }

      sourcesByEntitlement[entitlementId] = sources

      // Every source that is granting names a product that is genuinely paid
      // for, not just the one describing the entitlement. A group in its
      // billing grace period alongside a group with more time left on it is
      // still unlocking access, so its product counts as active too.
      for source in sources where source.isActive {
        grantingProductIds.insert(source.latestProductId)
      }

      // A source that grants nothing has been refunded or has run out, even when
      // one of its transactions still has a future expiry and no revocation
      // date. Its products stop counting as active, whatever another source is
      // doing for the same entitlement.
      for source in sources where !source.isActive {
        lapsedProductIds.formUnion(source.productIds)
      }

      // These variables describe the latest subscription on the device, so the
      // winner is the most recently bought one across every entitlement. Picking
      // it up here and reporting it once keeps it out of the hands of dictionary
      // iteration order.
      if let candidate = latestSubscriptionSource(from: sources),
        candidate.latestPurchaseDate > (latestSubscription?.latestPurchaseDate ?? .distantPast) {
        latestSubscription = candidate
      }
    }

    onGrantingProductIds?(grantingProductIds)
    // A product still granting through one entitlement is paid for, so it never
    // counts as lapsed because a narrower entitlement saw fewer of its renewals.
    onLapsedProductIds?(lapsedProductIds.subtracting(grantingProductIds))

    if let latestSubscription = latestSubscription {
      onLatestSubscriptionUpdate?(
        latestSubscription.state,
        latestSubscription.willRenew,
        latestSubscription.offerType
      )
    }

    subscriptions = updatedSubscriptions

    return buildEntitlements(
      from: transactionsByEntitlement,
      sourcesByEntitlement: sourcesByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )
  }
}

// MARK: - StoreKit Transaction Adapter
@available(iOS 15.0, *)
extension Transaction: EntitlementTransaction {
  var productId: String { productID }
  var transactionId: String { String(id) }
  var isRevoked: Bool { revocationDate != nil }

  var entitlementProductType: EntitlementTransactionType {
    switch self.productType {
    case .consumable:
      return .consumable
    case .nonConsumable:
      return .nonConsumable
    case .autoRenewable:
      return .autoRenewable
    case .nonRenewable:
      return .nonRenewable
    default:
      return .consumable
    }
  }

  var willRenew: Bool { false } // Will be set separately from subscription status
  var renewedAt: Date? {
    // Detect renewal by comparing original purchase date with purchase date
    originalPurchaseDate < purchaseDate ? purchaseDate : nil
  }

  var isInGracePeriod: Bool { false } // Will be updated later from subscription status
  var isInBillingRetryPeriod: Bool { false } // Will be updated later from subscription status
  var isActive: Bool {
    guard !isRevoked else { return false }
    if let expiration = expirationDate {
      return expiration > Date()
    }
    return entitlementProductType == .nonConsumable
  }

  var offerType: LatestSubscription.OfferType? {
    if #available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *) {
      #if compiler(>=6.0.0)
      if offer?.type == .winBack {
        return .winback
      }
      #endif
      guard let offer = offer else {
        return nil
      }
      switch offer.type {
      case .introductory:
        return .trial
      case .code:
        return .code
      case .promotional:
        return .promotional
      default:
        return nil
      }
    }
    return nil
  }

  var subscriptionGroupId: String? {
    subscriptionGroupID
  }
}
