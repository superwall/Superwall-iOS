//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/12/2022.
//

import Foundation
import StoreKit

protocol StoreTransactionType: Sendable {
  /// The date that App Store charged the user’s account for a purchased or restored product,
  /// or for a subscription purchase or renewal after a lapse.
  var transactionDate: Date? { get }

  /// The unique identifier for the transaction.
  var originalTransactionIdentifier: String { get }

  var state: StoreTransactionState { get }

  var storeTransactionId: String? { get }

  /// Info about the payment associated with the transaction
  var payment: StorePayment { get }
}

public enum StoreTransactionState: String, Codable, Sendable {
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
