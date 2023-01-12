//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/12/2022.
//
// swiftlint:disable strict_fileprivate

import StoreKit

/// TypeAlias to StoreKit 1's Transaction type, called `StoreKit/SKPaymentTransaction`
public typealias SK1Transaction = SKPaymentTransaction

@objc(SWKStoreTransaction)
@objcMembers
public final class StoreTransaction: NSObject, StoreTransactionType, Encodable {
  /// A string that uniquely identifies the transaction. Used on the server.
  private let id = UUID().uuidString

  public let configRequestId: String
  public let appSessionId: String
  public let triggerSessionId: String?

  public let underlyingSK1Transaction: SK1Transaction
  public let transactionDate: Date?
  public let originalTransactionIdentifier: String
  public let state: StoreTransactionState
  public let storeTransactionId: String?
  public let payment: StorePayment

  init(
    transaction: SK1Transaction,
    configRequestId: String,
    appSessionId: String,
    triggerSessionId: String?
  ) {
    self.underlyingSK1Transaction = transaction
    self.configRequestId = configRequestId
    self.appSessionId = appSessionId
    self.triggerSessionId = triggerSessionId

    transactionDate = transaction.transactionDate
    originalTransactionIdentifier = transaction.transactionID
    state = StoreTransactionState(from: transaction.transactionState)
    storeTransactionId = transaction.transactionIdentifier
    payment = StorePayment(from: transaction.payment)
  }

  public enum CodingKeys: String, CodingKey {
    case id
    case configRequestId
    case appSessionId
    case triggerSessionId
    case transactionDate
    case originalTransactionIdentifier
    case state
    case storeTransactionId
    case payment
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(configRequestId, forKey: .configRequestId)
    try container.encode(appSessionId, forKey: .appSessionId)
    try container.encodeIfPresent(triggerSessionId, forKey: .triggerSessionId)
    try container.encodeIfPresent(transactionDate, forKey: .transactionDate)
    try container.encode(originalTransactionIdentifier, forKey: .originalTransactionIdentifier)
    try container.encode(state, forKey: .state)
    try container.encodeIfPresent(storeTransactionId, forKey: .storeTransactionId)
    try container.encode(payment, forKey: .payment)
    try container.encode(id, forKey: .id)
  }
}

extension SKPaymentTransaction {
  fileprivate var transactionID: String {
    guard let identifier = self.transactionIdentifier else {
      return UUID().uuidString
    }

    return identifier
  }
}
