//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import Foundation
import StoreKit

struct TransactionModel: Codable {
  /// A string that uniquely identifies the transaction.
  private var id = UUID().uuidString

  enum TransactionState: String, Codable {
    case purchasing = "PURCHASING"
    case purchased = "PURCHASED"
    case failed = "FAILED"
    case restored = "RESTORED"
    case deferred = "DEFERRED"

    init(from transactionState: SKPaymentTransactionState) {
      switch transactionState {
      case .deferred:
        self = .deferred
      case .failed:
        self = .failed
      case .purchased:
        self = .purchased
      case .purchasing:
        self = .purchasing
      case .restored:
        self = .restored
      @unknown default:
        self = .purchasing
      }
    }
  }
  /// The current state of the transaction.
  let state: TransactionState

  /// The id of the config request
  let configRequestId: String

  /// The ID of the app session.
  var appSessionId: String

  /// The ID of the active trigger.
  let triggerSessionId: String?

  /// A string that uniquely identifies a successful payment transaction.
  let storeTransactionId: String?

  /// When the transaction state is restored, this contains the restored transaction id, otherwise it's nil.
  let originalTransactionIdentifier: String?

  /// The date when the transaction was added to the server queue.  Only valid if state is SKPaymentTransactionStatePurchased or SKPaymentTransactionStateRestored.
  let transactionDate: Date?

  /// Info about the payment associated with the transaction
  let payment: Payment

  // MARK: iOS 15 only properties
  /// The date of purchase for the original transaction.
  var originalTransactionDate: Date?

  /// The date of purchase for the original transaction.
  var webOrderLineItemID: String?

  /// The bundle identifier for the app.
  var appBundleId: String?

  /// The identifier of the subscription group that the subscription belongs to.
  var subscriptionGroupId: String?

  /// A Boolean that indicates whether the user upgraded to another subscription.
  var isUpgraded: Bool?

  /// The date the subscription expires or renews.
  var expirationDate: Date?

  /// A string that identifies an offer applied to the current subscription.
  var offerId: String?

  /// The date that App Store refunded the transaction or revoked it from family sharing.
  var revocationDate: Date?

  /// A UUID that associates the transaction with a user on your own service.
  var appAccountToken: UUID?

  init(
    from transaction: SKPaymentTransaction,
    configRequestId: String,
    appSessionId: String,
    triggerSessionId: String?
  ) {
    state = TransactionState(from: transaction.transactionState)
    self.configRequestId = configRequestId
    self.appSessionId = appSessionId
    self.triggerSessionId = triggerSessionId
    self.storeTransactionId = transaction.transactionIdentifier
    originalTransactionIdentifier = transaction.original?.transactionIdentifier
    transactionDate = transaction.transactionDate
    payment = Payment(from: transaction.payment)
  }

  @available(iOS 15.0, *)
  init(
    from transaction: Transaction,
    configRequestId: String,
    appSessionId: String,
    triggerSessionId: String?
  ) {
    state = TransactionState(from: .purchased)
    self.configRequestId = configRequestId
    self.appSessionId = appSessionId
    self.triggerSessionId = triggerSessionId
    self.storeTransactionId = "\(transaction.id)"
    originalTransactionIdentifier = "\(transaction.originalID)"
    transactionDate = transaction.purchaseDate
    originalTransactionDate = transaction.originalPurchaseDate
    webOrderLineItemID = transaction.webOrderLineItemID
    appBundleId = transaction.appBundleID
    subscriptionGroupId = transaction.subscriptionGroupID
    isUpgraded = transaction.isUpgraded
    expirationDate = transaction.expirationDate
    offerId = transaction.offerID
    revocationDate = transaction.revocationDate
    appAccountToken = transaction.appAccountToken
    payment = Payment(from: transaction)
  }
}

extension TransactionModel: Stubbable {
  static func stub() -> TransactionModel {
    return TransactionModel(
      from: SKPaymentTransaction(),
      configRequestId: "abc",
      appSessionId: "123",
      triggerSessionId: nil
    )
  }
}
