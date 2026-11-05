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

@available(iOS 17.2, macOS 14.2, watchOS 10.2, tvOS 17.2, *)
extension ObserverModeTracker {
  /// Records the transactions made before observer mode was turned on as
  /// handled, the first time it's on, so detection doesn't track them.
  func cacheLegacyTransactions() {
    operations.enqueue { [weak self] in
      await self?.cacheLegacyTransactionsNow()
    }
  }

  private func cacheLegacyTransactionsNow() async {
    if state.didCacheLegacyTransactions {
      return
    }
    let allTransactions = await allTransactionsProvider.getAllTransactions()
    let legacyTransactionIds = Set(allTransactions.map { $0.underlyingTransaction.id })
    store.update(ObserverModeUpdate.cachedLegacyTransactions(legacyTransactionIds))
  }

  /// Tracks the latest StoreKit 2 purchase if the app made it itself and it
  /// hasn't been handled yet. Detections run one at a time, after the legacy
  /// transactions have been cached.
  func detectUnobservedTransactions() async {
    await operations.run { [weak self] in
      await self?.detectUnobservedTransactionsNow()
    }
  }

  private func detectUnobservedTransactionsNow() async {
    // Legacy transactions are cached ahead of any detection, unless observer
    // mode was off at launch.
    if !state.didCacheLegacyTransactions {
      return
    }

    // Check that a Superwall purchase hasn't already started.
    // This could race with a transactionDidSucceed, however, in that function
    // we insert the transaction ID into the cache. That means that even if it
    // races, we won't continue. This needs to be here incase this calls before
    // transactionDidSucceed.
    let source = await factory.makePurchasingCoordinator().source
    if source != nil {
      return
    }

    let allTransactions = await allTransactionsProvider.getAllTransactions()

    // Clear saved transaction IDs if empty transaction list, e.g. if removed from Xcode transactions.
    if allTransactions.isEmpty {
      store.update(ObserverModeUpdate.clearedSyncedTransactions)
    }

    guard
      let mostRecentTransaction = await allTransactionsProvider.getMostRecentVerifiedTransaction(
        from: allTransactions
      ),
      let transaction = mostRecentTransaction.verifiedTransaction
    else {
      return
    }

    // Mark every transaction as handled, unless the latest one already was.
    var isNew = false
    store.dispatch(
      ObserverModeAction.claimUnsyncedTransactions(
        transactionIds: Set(allTransactions.map { $0.underlyingTransaction.id }),
        latestTransactionId: transaction.id
      ) { isNew = $0 },
      in: self
    )
    if !isNew {
      return
    }

    // Check that the transaction reason is purchase and not renewal.
    if transaction.reason != .purchase {
      return
    }

    await logPurchase(transaction)
  }

  private func logPurchase(_ transaction: SK2Transaction) async {
    guard let product = try? await productsManager.products(
      identifiers: [transaction.productID],
      forPaywall: nil,
      placement: nil
    ).first else {
      return
    }
    let transactionManager = factory.makeTransactionManager()
    await transactionManager.prepareToPurchase(
      product: product,
      purchaseSource: .observeFunc(product)
    )

    let hasOffer = transaction.offer != nil
    let coordinator = factory.makePurchasingCoordinator()
    await coordinator.setIsFreeTrialAvailable(to: hasOffer)

    await transactionManager.didPurchase()
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
