//
//  File.swift
//
//
//  Created by Yusuf Tör on 07/12/2022.
//

import StoreKit

struct SK1StoreTransaction: StoreTransactionType {
  let underlyingSK1Transaction: SK1Transaction

  public let transactionDate: Date?
  public let originalTransactionIdentifier: String
  public let state: StoreTransactionState
  public let storeTransactionId: String?
  public let originalTransactionDate: Date?
  public let webOrderLineItemID: String?
  public let appBundleId: String?
  public let subscriptionGroupId: String?
  public let isUpgraded: Bool?
  public let expirationDate: Date?
  public let offerId: String?
  public let revocationDate: Date?
  public let appAccountToken: UUID?
  public let payment: StorePayment

  init(transaction: SK1Transaction) {
    self.underlyingSK1Transaction = transaction

    transactionDate = transaction.transactionDate
    originalTransactionIdentifier = transaction.transactionID
    state = StoreTransactionState(from: transaction.transactionState)
    storeTransactionId = transaction.transactionIdentifier
    originalTransactionDate = nil
    webOrderLineItemID = nil
    appBundleId = nil
    subscriptionGroupId = nil
    isUpgraded = nil
    expirationDate = nil
    offerId = nil
    revocationDate = nil
    appAccountToken = nil
    payment = StorePayment(from: transaction.payment)
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
