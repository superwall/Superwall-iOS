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

/// Protocol for providing subscription status information
@available(iOS 15.0, *)
protocol SubscriptionStatusProvider {
  func getSubscriptionStatus(for transaction: Transaction) async -> StoreKit.Product.SubscriptionInfo.Status?
  func getWillAutoRenew(from status: StoreKit.Product.SubscriptionInfo.Status?) -> Bool
  func getSubscriptionState(from status: StoreKit.Product.SubscriptionInfo.Status?) -> LatestSubscription.State?
  @available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *)
  func getOfferType(from transaction: Transaction) -> LatestSubscription.OfferType?
}

/// Default implementation using StoreKit directly
@available(iOS 15.0, *)
struct StoreKitSubscriptionStatusProvider: SubscriptionStatusProvider {
  func getSubscriptionStatus(for transaction: Transaction) async -> StoreKit.Product.SubscriptionInfo.Status? {
    return await transaction.subscriptionStatus
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

  /// Process entitlements from transactions, enriching them with metadata
  static func buildEntitlementsFromTransactions(
    from transactionsByEntitlement: [String: [any EntitlementTransaction]],
    rawEntitlementsByProductId: [String: Set<Entitlement>],
    productIdsByEntitlementId: [String: Set<String>]
  ) -> [String: Set<Entitlement>] {
    var processedEntitlementsByProductId: [String: Set<Entitlement>] = [:]
    var mostRecentRenewableByEntitlement: [String: (any EntitlementTransaction)] = [:]
    let now = Date()

    // Process each entitlement group
    for (entitlementId, transactions) in transactionsByEntitlement {
      var isActive = false
      var renewedAt: Date?
      var expiresAt: Date?
      var mostRecentRenewable: (any EntitlementTransaction)?
      var latestProductId: String?

      let startsAt = transactions.last?.originalPurchaseDate
      var isLifetime = false

      // Check for lifetime products (non-consumable, non-revoked)
      if let lifetimeTransaction = transactions.first(where: {
        $0.entitlementProductType == .nonConsumable && !$0.isRevoked
      }) {
        isLifetime = true
        latestProductId = lifetimeTransaction.productId
        isActive = true
      }

      // Process transactions to determine active status and dates
      for transaction in transactions {
        // Check if transaction is active (non-revoked and not expired)
        if !transaction.isRevoked {
          if let expirationDate = transaction.expirationDate {
            if expirationDate > now {
              isActive = true
            }
          }
        }

        // Track most recent renewable transaction
        if !isLifetime,
          transaction.entitlementProductType == .autoRenewable || transaction.entitlementProductType == .nonRenewable {
          if let mostRecent = mostRecentRenewable {
            if mostRecent.purchaseDate < transaction.purchaseDate {
              mostRecentRenewable = transaction
            }
          } else {
            mostRecentRenewable = transaction
          }
        }

        // Track renewal date
        if transaction.entitlementProductType == .autoRenewable,
          !transaction.isRevoked {
          if transaction.originalPurchaseDate < transaction.purchaseDate,
            renewedAt == nil || renewedAt ?? Date() < transaction.purchaseDate {
            renewedAt = transaction.purchaseDate
          }
        }

        // Track latest expiration for non-lifetime
        if !isLifetime,
          transaction.entitlementProductType == .autoRenewable || transaction.entitlementProductType == .nonRenewable,
          !transaction.isRevoked,
          let expiration = transaction.expirationDate {
          if let currentExpiresAt = expiresAt {
            if currentExpiresAt < expiration {
              expiresAt = expiration
            }
          } else {
            expiresAt = expiration
          }
        }
      }

      if latestProductId == nil {
        latestProductId = mostRecentRenewable?.productId
      }

      // Store the most recent renewable for this entitlement (only if it exists)
      if let mostRecentRenewable = mostRecentRenewable {
        mostRecentRenewableByEntitlement[entitlementId] = mostRecentRenewable
      }

      // Find all product IDs for this entitlement from server config
      let productIds = productIdsByEntitlementId[entitlementId] ?? []

      for productId in productIds {
        // Get the raw entitlement info for this product
        if let rawEntitlements = rawEntitlementsByProductId[productId] {
          var enrichedEntitlements: Set<Entitlement> = []

          for rawEntitlement in rawEntitlements where rawEntitlement.id == entitlementId {
            let enrichedEntitlement = Entitlement(
              id: rawEntitlement.id,
              type: rawEntitlement.type,
              isActive: isActive,
              productIds: productIds,
              latestProductId: latestProductId,
              store: .appStore,
              startsAt: startsAt,
              renewedAt: renewedAt,
              expiresAt: expiresAt,
              isLifetime: isLifetime,
              willRenew: mostRecentRenewable?.willRenew ?? false,
              state: nil, // Will be set separately if needed
              offerType: nil // Will be set separately if needed
            )
            enrichedEntitlements.insert(enrichedEntitlement)
          }

          processedEntitlementsByProductId[productId, default: []].formUnion(enrichedEntitlements)
        }
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
    onLatestSubscriptionUpdate: ((LatestSubscription.State?, Bool?, LatestSubscription.OfferType?) -> Void)? = nil
  ) async -> [String: Set<Entitlement>] {
    // First, do the basic processing and build mostRecentRenewable lookup
    let basicEntitlementsByProductId = buildEntitlementsFromTransactions(
      from: transactionsByEntitlement,
      rawEntitlementsByProductId: rawEntitlementsByProductId,
      productIdsByEntitlementId: productIdsByEntitlementId
    )
    var finalEntitlementsByProductId = basicEntitlementsByProductId

    // Build mostRecentRenewable lookup for enhancement phase
    var mostRecentRenewableByEntitlement: [String: (any EntitlementTransaction)] = [:]
    for (entitlementId, transactions) in transactionsByEntitlement {
      var mostRecentRenewable: (any EntitlementTransaction)?
      let isLifetime = transactions.contains { $0.entitlementProductType == .nonConsumable && !$0.isRevoked }

      if !isLifetime {
        for transaction in transactions {
          if transaction.entitlementProductType == .autoRenewable || transaction.entitlementProductType == .nonRenewable {
            if let mostRecent = mostRecentRenewable {
              if mostRecent.purchaseDate < transaction.purchaseDate {
                mostRecentRenewable = transaction
              }
            } else {
              mostRecentRenewable = transaction
            }
          }
        }
      }

      if let mostRecentRenewable = mostRecentRenewable {
        mostRecentRenewableByEntitlement[entitlementId] = mostRecentRenewable
      }
    }

    // Then enhance with subscription status for StoreKit transactions
    for (entitlementId, transactions) in transactionsByEntitlement {
      let isLifetime = transactions.contains { $0.entitlementProductType == .nonConsumable && !$0.isRevoked }

      // one subscriptionStatus call per entitlement
      var willRenew = mostRecentRenewableByEntitlement[entitlementId]?.willRenew ?? false
      var state: LatestSubscription.State?
      var offerType: LatestSubscription.OfferType?

      let subscriptionTxnIndex: Array<SubscriptionTransaction>.Index?
      if let renewable = mostRecentRenewableByEntitlement[entitlementId] {
        subscriptionTxnIndex = subscriptions.firstIndex {
          $0.transactionId == renewable.transactionId
        }
      } else {
        subscriptionTxnIndex = nil
      }

      if !isLifetime,
        let renewableTransaction = mostRecentRenewableByEntitlement[entitlementId] as? Transaction {
        let status = await subscriptionStatusProvider.getSubscriptionStatus(for: renewableTransaction)

        willRenew = subscriptionStatusProvider.getWillAutoRenew(from: status)

        if let index = subscriptionTxnIndex {
          subscriptions[index].willRenew = willRenew
        }

        state = subscriptionStatusProvider.getSubscriptionState(from: status)

        if let index = subscriptionTxnIndex {
          subscriptions[index].isInGracePeriod = state == .inGracePeriod
          subscriptions[index].isInBillingRetryPeriod = state == .inBillingRetryPeriod
        }

        if #available(iOS 17.2, visionOS 1.1, *) {
          offerType = subscriptionStatusProvider.getOfferType(from: renewableTransaction)
        }

        // Call the callback for experimental device variables
        onLatestSubscriptionUpdate?(state, willRenew, offerType)
      }

      // Update processed entitlements with subscription-specific data
      let productIds = productIdsByEntitlementId[entitlementId] ?? []
      for productId in productIds {
        if let entitlements = finalEntitlementsByProductId[productId] {
          var updatedEntitlements: Set<Entitlement> = []
          for entitlement in entitlements where entitlement.id == entitlementId {
            let updatedEntitlement = Entitlement(
              id: entitlement.id,
              type: entitlement.type,
              isActive: entitlement.isActive,
              productIds: entitlement.productIds,
              latestProductId: entitlement.latestProductId,
              store: entitlement.store,
              startsAt: entitlement.startsAt,
              renewedAt: entitlement.renewedAt,
              expiresAt: entitlement.expiresAt,
              isLifetime: entitlement.isLifetime,
              willRenew: willRenew,
              state: state,
              offerType: offerType
            )
            updatedEntitlements.insert(updatedEntitlement)
          }
          // Add back other entitlements for this product
          for other in entitlements where other.id != entitlementId {
            updatedEntitlements.insert(other)
          }
          finalEntitlementsByProductId[productId] = updatedEntitlements
        }
      }
    }

    return finalEntitlementsByProductId
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
