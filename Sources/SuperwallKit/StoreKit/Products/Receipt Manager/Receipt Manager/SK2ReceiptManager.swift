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
  func loadPurchases() async -> Set<Purchase>
  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool
}

enum LatestSubscription {
  enum PeriodType: String {
    case trial
    case code
    case subscription
    case promotional
    case winback
    case revoked
  }

  enum State: String {
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

  func loadPurchases() async -> Set<Purchase> {
    var purchases: Set<Purchase> = []
    // Iterate through the user's purchased products.
    var originalTransactionIds: Set<UInt64> = []
    transactionReceipts = []
    var latestSubscriptionTransaction: Transaction?
    let enableExperimentalDeviceVariables = Superwall.shared.options.enableExperimentalDeviceVariables

    for await verificationResult in Transaction.all {
      switch verificationResult {
      case .verified(let transaction):
        // Track latest auto-renewable transaction
        if enableExperimentalDeviceVariables,
          transaction.productType == .autoRenewable {
          if let latest = latestSubscriptionTransaction {
            if transaction.purchaseDate > latest.purchaseDate {
              latestSubscriptionTransaction = transaction
            }
          } else {
            latestSubscriptionTransaction = transaction
          }
        }

        // Store the first transaction receipt for each original txn ID.
        let originalTransactionId = verificationResult.underlyingTransaction.originalID
        if originalTransactionId == transaction.id,
          !originalTransactionIds.contains(originalTransactionId) {
          transactionReceipts.append(
            TransactionReceipt(jwsRepresentation: verificationResult.jwsRepresentation)
          )
          originalTransactionIds.insert(originalTransactionId)
        }

        // If already expired, set as inactive
        if let expirationDate = transaction.expirationDate {
          if expirationDate < Date() {
            purchases.insert(
              Purchase(
                id: transaction.productID,
                isActive: false,
                purchaseDate: transaction.purchaseDate
              )
            )
            continue
          }
        }
        // If refunded/revoked, set as inactive
        if transaction.revocationDate != nil {
          purchases.insert(
            Purchase(
              id: transaction.productID,
              isActive: false,
              purchaseDate: transaction.purchaseDate
            )
          )
          continue
        }

        purchases.insert(
          Purchase(
            id: transaction.productID,
            isActive: true,
            purchaseDate: transaction.purchaseDate
          )
        )
      case let .unverified(transaction, error):
        Logger.debug(
          logLevel: .warn,
          scope: .transactions,
          message: "The purchased transactions contains an unverified transaction "
            + "\(transaction.debugDescription). \(error.localizedDescription)"
        )
      }
    }

    // Only check subscription status on the latest subscription transaction
    if enableExperimentalDeviceVariables,
      let transaction = latestSubscriptionTransaction {
      let status = await transaction.subscriptionStatus
      if case let .verified(renewalInfo) = status?.renewalInfo {
        if #available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *) {
          updatePeriodType(from: transaction)
        }
        latestSubscriptionWillAutoRenew = renewalInfo.willAutoRenew == true
      }
      updateLatestSubscriptionState(from: status)
    }

    self.purchases = purchases
    return purchases
  }

  @available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *)
  private func updatePeriodType(from transaction: Transaction) {
    #if compiler(>=6.0.0)
    if transaction.offer?.type == .winBack {
      latestSubscriptionPeriodType = .winback
      return
    }
    #endif
    switch transaction.offer?.type {
    case .introductory:
      latestSubscriptionPeriodType = .trial
    case .code:
      latestSubscriptionPeriodType = .code
    case .promotional:
      latestSubscriptionPeriodType = .promotional
    case .none:
      latestSubscriptionPeriodType = .subscription
    default:
      break
    }
  }

  private func updateLatestSubscriptionState(from status: StoreKit.Product.SubscriptionInfo.Status?) {
    switch status?.state {
    case .inGracePeriod:
      latestSubscriptionState = .inGracePeriod
    case .subscribed:
      latestSubscriptionState = .subscribed
    case .expired:
      latestSubscriptionState = .expired
    case .inBillingRetryPeriod:
      latestSubscriptionState = .inBillingRetryPeriod
    case .revoked:
      latestSubscriptionState = .revoked
    default:
      break
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
