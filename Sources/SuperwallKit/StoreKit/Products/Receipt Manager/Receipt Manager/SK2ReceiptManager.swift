//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/09/2024.
//
// swiftlint:disable function_body_length

import Foundation
import StoreKit

protocol ReceiptManagerType: AnyObject {
  var purchases: Set<Purchase> { get async }
  var transactionReceipts: [TransactionReceipt] { get async }
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType? { get async }
  var latestSubscriptionWillAutoRenew: Bool? { get async }
  var latestSubscriptionState: LatestSubscription.State? { get async }
  var appTransactionId: String? { get async }

  func loadIntroOfferEligibility(forProducts storeProducts: Set<StoreProduct>) async
  func loadPurchases(serverEntitlementsByProductId: [String: Set<Entitlement>]) async -> PurchaseSnapshot
  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool
}

struct PurchaseSnapshot {
  let purchases: Set<Purchase>
  let customerInfo: CustomerInfo
}

@available(iOS 15.0, *)
actor SK2ReceiptManager: ReceiptManagerType {
  private var sk2IntroOfferEligibility: [String: Bool]
  var purchases: Set<Purchase>
  var transactionReceipts: [TransactionReceipt]
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType?
  var latestSubscriptionWillAutoRenew: Bool?
  var latestSubscriptionState: LatestSubscription.State?
  var appTransactionId: String?

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
    var nonSubscriptions: [NonSubscriptionTransaction] = []
    var subscriptions: [SubscriptionTransaction] = []

    for (productId, serverEntitlements) in serverEntitlementsByProductId {
      for entitlement in serverEntitlements {
        // Collect all productIds for this entitlement ID
        productIdsByEntitlementId[entitlement.id, default: []].insert(productId)

        let allProductIds = productIdsByEntitlementId[entitlement.id] ?? [productId]

        entitlementsByProductId[productId, default: []].insert(
          Entitlement(
            id: entitlement.id,
            type: entitlement.type,
            isActive: false,  // Will be set to true by EntitlementProcessor if there are transactions
            productIds: allProductIds,
            store: entitlement.store
          )
        )
      }
    }

    // 1️⃣ FIRST PASS: collect txns & receipts & purchases
    var allVerifiedTransactions: [Transaction] = []

    for await verificationResult in Transaction.all {
      switch verificationResult {
      case .verified(let txn):
        allVerifiedTransactions.append(txn)

        // Get the entitlements for a purchased product.
        if let serverEntitlements = serverEntitlementsByProductId[txn.productID] {
          // Map transactions and their product IDs to each entitlement.
          for entitlement in serverEntitlements {
            txnsPerEntitlement[entitlement.id, default: []].append(txn)
          }
        }

        // first receipt per original txn
        let originalTxnId = verificationResult.underlyingTransaction.originalID
        if originalTxnId == txn.id,
          !originalTransactionIds.contains(originalTxnId) {
          transactionReceipts.append(
            TransactionReceipt(jwsRepresentation: verificationResult.jwsRepresentation)
          )
          originalTransactionIds.insert(originalTxnId)
        }

        // record purchase
        let isActive = isAnyTransactionActive([txn])
        purchases.insert(
          Purchase(
            id: txn.productID,
            isActive: isActive,
            purchaseDate: txn.purchaseDate
          )
        )
      case let .unverified(txn, error):
        Logger.debug(
          logLevel: .warn,
          scope: .transactions,
          message: "The purchased transactions contain an unverified transaction"
            + ": \(txn.debugDescription). \(error.localizedDescription)"
        )
      }
    }

    // Process transactions using shared EntitlementProcessor
    let (processedNonSubscriptions, processedSubscriptions) = EntitlementProcessor.processTransactions(
      from: allVerifiedTransactions
    )
    nonSubscriptions = processedNonSubscriptions
    subscriptions = processedSubscriptions

    // 2️⃣ & 3️⃣ SECOND AND THIRD PASS: use enhanced EntitlementProcessor
    var capturedState: LatestSubscription.State?
    var capturedWillRenew: Bool?
    var capturedOfferType: LatestSubscription.OfferType?

    entitlementsByProductId = await EntitlementProcessor.buildEntitlementsWithLiveSubscriptionData(
      from: txnsPerEntitlement,
      rawEntitlementsByProductId: entitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId,
      subscriptions: &subscriptions,
      subscriptionStatusProvider: StoreKitSubscriptionStatusProvider(),
      enableExperimentalDeviceVariables: enableExperimentalDeviceVariables
    ) { state, willRenew, offerType in
      capturedState = state
      capturedWillRenew = willRenew
      capturedOfferType = offerType
    }

    // Update actor-isolated properties after the async call
    if enableExperimentalDeviceVariables {
      latestSubscriptionState = capturedState
      latestSubscriptionWillAutoRenew = capturedWillRenew
      latestSubscriptionPeriodType = capturedOfferType
    }

    var entitlements = entitlementsByProductId.values
      .flatMap { $0 }
    entitlements = Array(Entitlement.mergePrioritized(entitlements))
      .sorted { $0.id < $1.id }

    self.purchases = purchases
    let customerInfo = CustomerInfo(
      subscriptions: subscriptions.reversed(),
      nonSubscriptions: nonSubscriptions.reversed(),
      entitlements: entitlements
    )

    return PurchaseSnapshot(
      purchases: purchases,
      customerInfo: customerInfo
    )
  }


  private func isAnyTransactionActive(_ transactions: [Transaction]) -> Bool {
    let now = Date()

    return transactions.contains { txn in
      guard txn.revocationDate == nil else {
        return false
      }
      if let expiration = txn.expirationDate {
        return expiration > now
      }
      return txn.productType == .nonConsumable
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
