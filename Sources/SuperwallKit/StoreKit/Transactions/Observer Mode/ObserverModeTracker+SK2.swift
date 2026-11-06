//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  ObserverModeTracker+SK2.swift
//
//  Created by Will Taylor on 5/1/24.
//  Modified by Yusuf Tor

import Foundation
import StoreKit

extension ObserverModeTracker {
  func fetchTransactions() async -> StoreKitTransactions {
    let allTransactions = await allTransactionsProvider.getAllTransactions()
    let ids = Set(allTransactions.map { $0.underlyingTransaction.id })
    guard
      #available(iOS 17.2, macOS 14.2, visionOS 1.1, watchOS 10.2, tvOS 17.2, *),
      let latest = await allTransactionsProvider.getMostRecentVerifiedTransaction(
        from: allTransactions
      )?.verifiedTransaction
    else {
      return StoreKitTransactions(ids: ids, latest: nil)
    }
    return StoreKitTransactions(
      ids: ids,
      latest: ObservedTransaction(
        id: latest.id,
        productId: latest.productID,
        isPurchase: latest.reason == .purchase,
        startedOffer: latest.offer != nil
      )
    )
  }
}

/// A wrapper protocol that allows for abstracting out calls to an `AsyncSequence<VerificationResult<Transaction>>`.
/// This will usually be `Transaction.all` in production but allows us to inject custom AsyncSequences for testing.
protocol AllTransactionsProviderType: Sendable {
  func getAllTransactions() async -> [StoreKit.VerificationResult<StoreKit.Transaction>]
  func getMostRecentVerifiedTransaction(
    from transactions: [StoreKit.VerificationResult<StoreKit.Transaction>]
  ) async -> StoreKit.VerificationResult<StoreKit.Transaction>?
}

/// A concretete implementation of `AllTransactionsProviderType` that fetches
/// transactions from StoreKit's ``StoreKit/Transaction/all``
struct SK2AllTransactionsProvider: AllTransactionsProviderType, Sendable {
  func getAllTransactions() async -> [StoreKit.VerificationResult<StoreKit.Transaction>] {
    return await StoreKit.Transaction.all.extractValues()
  }

  func getMostRecentVerifiedTransaction(
    from transactions: [StoreKit.VerificationResult<StoreKit.Transaction>]
  ) async -> StoreKit.VerificationResult<StoreKit.Transaction>? {
    let verifiedTransactions = transactions.filter { transaction in
      return transaction.verifiedTransaction != nil
    }
    if verifiedTransactions.isEmpty { return nil }
    guard let mostRecentTransaction = verifiedTransactions.max(by: {
      $0.verifiedTransaction?.purchaseDate ?? .distantPast < $1.verifiedTransaction?.purchaseDate ?? .distantPast
    }) else { return nil }

    return mostRecentTransaction
  }
}
