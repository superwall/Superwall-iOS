//
//  ObserverModeState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

typealias ObserverModeStore = StateStore<ObserverModeContext, ObserverModeState>

/// What ``ObserverModeAction``s need. ``ObserverModeTracker`` provides it.
protocol ObserverModeContext: AnyObject {
  var store: ObserverModeStore { get }
}

/// What the SDK remembers about purchases the app makes itself, when
/// `shouldObservePurchases` is on. Changed only by ``ObserverModeUpdate``
/// reducers on ``ObserverModeTracker``'s store, which saves every change.
struct ObserverModeState: Equatable {
  /// The products of StoreKit 1 purchases the app started that are being
  /// observed, so a purchase put back on the payment queue isn't observed
  /// twice. Saved as `PurchasingProductIds`.
  var purchasingProductIds: Set<String> = []
  /// The StoreKit 2 transactions already handled, so each is tracked at most
  /// once. Saved as `SK2TransactionIds`.
  var syncedTransactionIds: Set<UInt64> = []
  /// Whether the transactions made before observer mode was turned on have
  /// been added to ``syncedTransactionIds``. Saved as
  /// `DidCacheLegacyTransactions`.
  var didCacheLegacyTransactions = false
}

/// The ways ``ObserverModeState`` can change.
enum ObserverModeUpdate: Reducer {
  /// The app started a StoreKit 1 purchase of the product.
  case startedPurchasing(productId: String)
  /// StoreKit removed these products' transactions from the payment queue.
  case removedFromQueue(productIds: Set<String>)
  /// These StoreKit 2 transactions have been handled.
  case synced(transactionIds: Set<UInt64>)
  /// StoreKit has no transactions, for example after they were deleted in
  /// Xcode, so none are remembered.
  case clearedSyncedTransactions
  /// These are the transactions made before observer mode was turned on.
  case cachedLegacyTransactions(Set<UInt64>)

  func reduce(_ state: ObserverModeState) -> ObserverModeState {
    var state = state
    switch self {
    case .startedPurchasing(let productId):
      state.purchasingProductIds.insert(productId)
    case .removedFromQueue(let productIds):
      state.purchasingProductIds.subtract(productIds)
    case .synced(let transactionIds):
      state.syncedTransactionIds.formUnion(transactionIds)
    case .clearedSyncedTransactions:
      state.syncedTransactionIds = []
    case .cachedLegacyTransactions(let transactionIds):
      state.syncedTransactionIds.formUnion(transactionIds)
      state.didCacheLegacyTransactions = true
    }
    return state
  }
}

/// Checks and changes ``ObserverModeState`` in one step, so two threads can't
/// both decide to handle the same purchase.
enum ObserverModeAction: StoreAction {
  /// Starts observing the StoreKit 1 purchase of `productId` unless it's
  /// already observed, and tells `claimed` whether this call started it.
  case claimSK1Purchase(productId: String, claimed: (Bool) -> Void)
  /// Marks `transactionIds` as handled unless `latestTransactionId` already
  /// was, and tells `claimed` whether this call marked them.
  case claimUnsyncedTransactions(
    transactionIds: Set<UInt64>,
    latestTransactionId: UInt64,
    claimed: (Bool) -> Void
  )

  func execute(in context: ObserverModeContext) {
    let store = context.store
    switch self {
    case let .claimSK1Purchase(productId, claimed):
      if store.state.purchasingProductIds.contains(productId) {
        claimed(false)
        return
      }
      store.update(ObserverModeUpdate.startedPurchasing(productId: productId))
      claimed(true)
    case let .claimUnsyncedTransactions(transactionIds, latestTransactionId, claimed):
      if store.state.syncedTransactionIds.contains(latestTransactionId) {
        claimed(false)
        return
      }
      store.update(ObserverModeUpdate.synced(transactionIds: transactionIds))
      claimed(true)
    }
  }
}
