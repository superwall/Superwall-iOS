//
//  StoreKitTransactionLookup.swift
//  SuperwallKit
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation
import StoreKit

protocol StoreKitTransactionLooking: Sendable {
  func latestTransactionID(for productId: String) async -> UInt64?
  func isFamilyShared(productId: String) async -> Bool
}

@available(iOS 15.0, *)
struct StoreKitTransactionLookup: StoreKitTransactionLooking {
  func latestTransactionID(for productId: String) async -> UInt64? {
    guard case .verified(let transaction)? = await Transaction.latest(for: productId) else {
      return nil
    }
    return transaction.id
  }

  func isFamilyShared(productId: String) async -> Bool {
    guard case .verified(let transaction)? = await Transaction.latest(for: productId) else {
      return false
    }
    return transaction.ownershipType == .familyShared
  }
}
