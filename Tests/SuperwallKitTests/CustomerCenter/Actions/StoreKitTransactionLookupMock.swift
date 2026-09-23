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

  func latestTransactionID(for productId: String) async -> UInt64? {
    transactionIDs[productId]
  }

  func isFamilyShared(productId: String) async -> Bool {
    familyShared.contains(productId)
  }
}
