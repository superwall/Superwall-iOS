//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import Foundation
import StoreKit

struct TransactionModel: Codable {
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
  let id: String?

  /// When the transaction state is restored, this contains the restored transaction id, otherwise it's nil.
  let originalTransactionIdentifier: String?

  /// The date when the transaction was added to the server queue.  Only valid if state is SKPaymentTransactionStatePurchased or SKPaymentTransactionStateRestored.
  let transactionDate: Date?

  /// Info about the payment associated with the transaction
  let payment: Payment

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
    id = transaction.transactionIdentifier
    originalTransactionIdentifier = transaction.original?.transactionIdentifier
    transactionDate = transaction.transactionDate
    payment = Payment(from: transaction.payment)
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
