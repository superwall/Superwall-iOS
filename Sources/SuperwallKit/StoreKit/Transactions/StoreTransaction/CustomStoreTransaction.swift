//
//  CustomStoreTransaction.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-03-12.
//

import Foundation

/// A `StoreTransactionType` for custom products purchased through an external
/// purchase controller. The transaction ID is pre-generated before purchase.
struct CustomStoreTransaction: StoreTransactionType {
  let transactionDate: Date?
  let originalTransactionIdentifier: String
  let state: StoreTransactionState
  let storeTransactionId: String?
  let payment: StorePayment
  let originalTransactionDate: Date?
  let webOrderLineItemID: String? = nil
  let appBundleId: String? = nil
  let subscriptionGroupId: String? = nil
  let isUpgraded: Bool? = nil
  let expirationDate: Date? = nil
  let offerId: String? = nil
  let revocationDate: Date? = nil
  let appAccountToken: UUID? = nil

  init(
    customTransactionId: String,
    productIdentifier: String,
    purchaseDate: Date = Date()
  ) {
    self.transactionDate = purchaseDate
    self.originalTransactionIdentifier = customTransactionId
    self.state = .purchased
    self.storeTransactionId = customTransactionId
    self.payment = StorePayment(productIdentifier: productIdentifier)
    self.originalTransactionDate = purchaseDate
  }
}
