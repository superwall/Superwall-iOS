//
//  StoreKitTransactionLookupMock.swift
//  SuperwallKitTests
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation
@testable import SuperwallKit

final class StoreKitTransactionLookupMock: StoreKitTransactionLooking, @unchecked Sendable {
  var transactionIDs: [String: UInt64] = [:]
  var familyShared: Set<String> = []
  /// Holds `latestTransactionID(for:)` open until `releaseTransactionLookup()` when set.
  var holdsTransactionLookup = false
  private(set) var isHoldingTransactionLookup = false
  private var transactionLookupGate: CheckedContinuation<Void, Never>?

  func latestTransactionID(for productId: String) async -> UInt64? {
    if holdsTransactionLookup {
      await withCheckedContinuation { continuation in
        transactionLookupGate = continuation
        isHoldingTransactionLookup = true
      }
    }
    return transactionIDs[productId]
  }

  func releaseTransactionLookup() {
    transactionLookupGate?.resume()
    transactionLookupGate = nil
  }

  func isFamilyShared(productId: String) async -> Bool {
    familyShared.contains(productId)
  }
}
