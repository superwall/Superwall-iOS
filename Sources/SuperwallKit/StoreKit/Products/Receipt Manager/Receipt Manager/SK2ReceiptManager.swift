//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/09/2024.
//
// swiftlint:disable function_body_length cyclomatic_complexity

import Foundation
import StoreKit

protocol ReceiptManagerType: AnyObject {
  var purchases: Set<Purchase> { get async }
  var transactionReceipts: [TransactionReceipt] { get async }
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType? { get async }
  var latestSubscriptionWillAutoRenew: Bool? { get async }
  var latestSubscriptionState: LatestSubscription.State? { get async }

  func loadIntroOfferEligibility(forProducts storeProducts: Set<StoreProduct>) async
  func loadPurchases(serverEntitlementsByProductId: [String: Set<Entitlement>]) async -> PurchaseSnapshot
  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool
}

struct PurchaseSnapshot {
  let purchases: Set<Purchase>
  let entitlementsByProductId: [String: Set<Entitlement>]
  let nonSubscriptions: [NonSubscriptionTransaction]
  let activeSubscriptions: Set<String>
}

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

@available(iOS 15.0, *)
actor SK2ReceiptManager: ReceiptManagerType {
  private var sk2IntroOfferEligibility: [String: Bool]
  var purchases: Set<Purchase>
  var transactionReceipts: [TransactionReceipt]
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType?
  var latestSubscriptionWillAutoRenew: Bool?
  var latestSubscriptionState: LatestSubscription.State?

  init(
    sk2IntroOfferEligibility: [String: Bool] = [:],
    purchases: Set<Purchase> = [],
    transactionReceipts: [TransactionReceipt] = [],
    latestSubscriptionPeriodType: LatestSubscription.PeriodType? = nil,
    latestSubscriptionWillAutoRenew: Bool? = nil,
    latestSubscriptionState: LatestSubscription.State? = nil
  ) {
    self.sk2IntroOfferEligibility = sk2IntroOfferEligibility
    self.purchases = purchases
    self.transactionReceipts = transactionReceipts
    self.latestSubscriptionPeriodType = latestSubscriptionPeriodType
    self.latestSubscriptionWillAutoRenew = latestSubscriptionWillAutoRenew
    self.latestSubscriptionState = latestSubscriptionState
  }

  func loadIntroOfferEligibility(forProducts storeProducts: Set<StoreProduct>) async {
    for storeProduct in storeProducts {
      sk2IntroOfferEligibility[storeProduct.productIdentifier] = await isEligibleForIntroOffer(storeProduct)
    }
  }

  func loadPurchases(serverEntitlementsByProductId: [String: Set<Entitlement>]) async -> PurchaseSnapshot {
    var purchases: Set<Purchase> = []
    var originalTransactionIds: Set<UInt64> = []
    transactionReceipts = []
    let enableExperimentalDeviceVariables = Superwall.shared.options.enableExperimentalDeviceVariables

    // per-entitlement groupings
    var entitlementsByProductId: [String: Set<Entitlement>] = [:]
    var productIdsByEntitlementId: [String: Set<String>] = [:]
    var txnsPerEntitlement: [String: [Transaction]] = [:]

    for (productId, serverEntitlements) in serverEntitlementsByProductId {
      for entitlement in serverEntitlements {
        // Collect all productIds for this entitlement ID
        productIdsByEntitlementId[entitlement.id, default: []].insert(productId)
      }
    }

    for (productId, serverEntitlements) in serverEntitlementsByProductId {
      for entitlement in serverEntitlements {
        let allProductIds = productIdsByEntitlementId[entitlement.id] ?? [productId]

        entitlementsByProductId[productId, default: []].insert(
          Entitlement(
            id: entitlement.id,
            type: entitlement.type,
            productIds: allProductIds
          )
        )
      }
    }

    var nonSubscriptions: [NonSubscriptionTransaction] = []
    var activeSubscriptions: Set<String> = []

    // 1️⃣ FIRST PASS: collect txns & receipts & purchases
    for await verificationResult in Transaction.all {
      switch verificationResult {
      case .verified(let transaction):
        if transaction.productType != .nonConsumable {
          nonSubscriptions.append(
            NonSubscriptionTransaction(
              transactionId: transaction.id,
              productId: transaction.productID,
              purchaseDate: transaction.purchaseDate
            )
          )
        }

        // Get the entitlements for a purchased product.
        if let serverEntitlements = serverEntitlementsByProductId[transaction.productID] {
          // Map transactions and their product IDs to each entitlement.
          for entitlement in serverEntitlements {
            txnsPerEntitlement[entitlement.id, default: []].append(transaction)
          }
        }

        // first receipt per original txn
        let originalTxnId = verificationResult.underlyingTransaction.originalID
        if originalTxnId == transaction.id,
          !originalTransactionIds.contains(originalTxnId) {
          transactionReceipts.append(
            TransactionReceipt(jwsRepresentation: verificationResult.jwsRepresentation)
          )
          originalTransactionIds.insert(originalTxnId)
        }

        // record purchase
        let isActive = isAnyTransactionActive([transaction])
        purchases.insert(
          Purchase(
            id: transaction.productID,
            isActive: isActive,
            purchaseDate: transaction.purchaseDate
          )
        )
      case .unverified(let transaction, let error):
        Logger.debug(
          logLevel: .warn,
          scope: .transactions,
          message: "The purchased transactions contain an unverified transaction: \(transaction.debugDescription). \(error.localizedDescription)"
        )
      }
    }

    // 2️⃣ SECOND PASS: build entitlements, single subscriptionStatus call
    for (entitlementId, transactions) in txnsPerEntitlement {
      let now = Date()

      var isActive = false
      var renewedAt: Date?
      var expiresAt: Date?
      var mostRecentRenewable: Transaction?
      var latestProductId: String?

      // Can't be done in the next loop
      let startsAt = transactions.last?.originalPurchaseDate
      var isLifetime = false
      if let lifetimeProduct = transactions.filter({
        $0.productType == .nonConsumable &&
        $0.revocationDate == nil
      }).first {
        isLifetime = true
        latestProductId = lifetimeProduct.productID
      }
      
      // single scan of this entitlement's txns
      for txn in transactions {
        // any non-revoked, unexpired
        if txn.revocationDate == nil,
          let exp = txn.expirationDate,
          exp > now {
          activeSubscriptions.insert(txn.productID)
          isActive = true
        }

        if !isLifetime,
          mostRecentRenewable == nil ||
          mostRecentRenewable?.purchaseDate ?? Date() < txn.purchaseDate {
          // Track latest autoRenewable
          mostRecentRenewable = txn
        }

        if txn.productType == .autoRenewable,
          txn.revocationDate == nil {
          // Track renewal
          if txn.originalPurchaseDate < txn.purchaseDate,
            renewedAt == nil || renewedAt ?? Date() < txn.purchaseDate {
            renewedAt = txn.purchaseDate
          }
        }

        // latest expiration for non-lifetime
        if !isLifetime,
          (txn.productType == .autoRenewable || txn.productType == .nonRenewable),
          txn.revocationDate == nil,
          let exp = txn.expirationDate {
          if expiresAt == nil || exp > expiresAt! {
            expiresAt = exp
          }
        }
      }

      if latestProductId == nil {
        latestProductId = mostRecentRenewable?.productID
      }

      var productIds = productIdsByEntitlementId[entitlementId] ?? []

      // one subscriptionStatus call per entitlement
      var willRenew = false
      var state: LatestSubscription.State?
      var offerType: LatestSubscription.OfferType?

      if !isLifetime,
        let renewable = mostRecentRenewable {
        let status = await renewable.subscriptionStatus

        if case let .verified(info) = status?.renewalInfo {
          willRenew = info.willAutoRenew
          if enableExperimentalDeviceVariables {
            latestSubscriptionWillAutoRenew = info.willAutoRenew
          }
        }

        state = getLatestSubscriptionState(from: status)
        if enableExperimentalDeviceVariables {
          latestSubscriptionState = state
        }

        if #available(iOS 17.2, *) {
          offerType = getOfferType(from: renewable)
          if enableExperimentalDeviceVariables {
            latestSubscriptionPeriodType = offerType
          }
        }
      }

      // assemble and insert entitlements
      for id in productIds {
        var entitlements = entitlementsByProductId[id] ?? []
        var existingType: EntitlementType = .serviceLevel

        // Remove existing entitlement with same ID, if any
        if let existing = entitlements.first(where: { $0.id == entitlementId }) {
          existingType = existing.type
          productIds = existing.productIds
          entitlements.remove(existing)
        }

        // Insert updated entitlement
        entitlements.insert(
          Entitlement(
            id: entitlementId,
            type: existingType,
            isActive: isActive,
            productIds: productIds,
            latestProductId: latestProductId,
            startsAt: startsAt,
            renewedAt: renewedAt,
            expiresAt: expiresAt,
            isLifetime: isLifetime,
            willRenew: willRenew,
            state: state,
            offerType: offerType
          )
        )

        // Write back to the dictionary
        entitlementsByProductId[id] = entitlements
      }
    }

    self.purchases = purchases

    return PurchaseSnapshot(
      purchases: purchases,
      entitlementsByProductId: entitlementsByProductId,
      nonSubscriptions: nonSubscriptions.reversed(),
      activeSubscriptions: activeSubscriptions
    )
  }

  private func isAnyTransactionActive(_ transactions: [Transaction]) -> Bool {
    let now = Date()

    return transactions.contains { txn in
      guard txn.revocationDate == nil else {
        return false
      }
      guard let expiration = txn.expirationDate else {
        return false
      }
      return expiration > now
    }
  }

  private func latestExpirationDate(from transactions: [Transaction]) -> Date? {
    var latestExpiration: Date?

    for txn in transactions {
      switch txn.productType {
      case .autoRenewable,
        .nonRenewable:
        guard txn.revocationDate == nil else { continue }
        if let expiration = txn.expirationDate {
          latestExpiration = latestExpiration.map { max($0, expiration) } ?? expiration
        }
      case .nonConsumable:
        // If it's lifetime, it never expires - return nil
        return nil
      default:
        continue
      }
    }

    return latestExpiration
  }

  @available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *)
  private func getOfferType(from transactions: [Transaction]) -> LatestSubscription.PeriodType? {
    // Find most recent non-revoked transaction
    if let latest = getMostRecentRenewableSubscription(from: transactions) {
      return getOfferType(from: latest)
    }

    return nil
  }

  /// Gets the most recent transaction that isn't revoked.
  private func getMostRecentRenewableSubscription(from transactions: [Transaction]) -> Transaction? {
    return transactions
      .filter {
        $0.revocationDate == nil &&
        $0.productType == .autoRenewable
      }
      .max { $0.purchaseDate < $1.purchaseDate }
  }

  @available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *)
  private func getOfferType(from transaction: Transaction) -> LatestSubscription.PeriodType? {
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

  private func getLatestSubscriptionState(from status: StoreKit.Product.SubscriptionInfo.Status?) -> LatestSubscription.State? {
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

  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool {
    guard let product = storeProduct.product as? SK2StoreProduct else {
      return false
    }
    if let eligibility = sk2IntroOfferEligibility[storeProduct.productIdentifier] {
      return eligibility
    }
    guard product.hasFreeTrial else {
      return false
    }
    let sk2Product = product.underlyingSK2Product
    guard let renewableSubscription = sk2Product.subscription else {
      // Technically this is covered in hasFreeTrial, but good for unwrapping subscription
      return false
    }
    if await renewableSubscription.isEligibleForIntroOffer {
      // The product is eligible for an introductory offer.
      return true
    }
    return false
  }
}
