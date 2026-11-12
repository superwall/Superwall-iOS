//
//  ObserverModeState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

typealias ObserverModeStore = StateStore<ObserverModeContext, ObserverModeState>

/// What the SDK remembers about purchases the app makes itself, when
/// `shouldObservePurchases` is on. Changed only by ``ObserverModeUpdate``
/// events, through ``ObserverModeAction``s on ``ObserverModeTracker``'s store.
struct ObserverModeState: Equatable {
  /// The products of StoreKit 1 purchases the app started that are being
  /// observed, so a purchase put back on the payment queue isn't observed
  /// twice. Saved as `PurchasingProductIds`.
  var purchasingProductIds: Set<String> = []
  /// The StoreKit 2 transactions already handled, so each is tracked at most
  /// once. Saved as `SK2TransactionIds`.
  var handledTransactionIds: Set<UInt64> = []
  /// Whether the transactions made before observer mode was turned on are
  /// in ``handledTransactionIds``. Saved as `DidCacheLegacyTransactions`.
  var legacyRecording: LegacyRecording = .notRecorded
}

/// Whether the transactions made before observer mode was turned on have
/// been recorded as handled. Until they have, StoreKit 2 detection doesn't
/// run, since it would track an old purchase as new. Recording runs on the
/// tracker's task lane, so it never runs twice at once.
enum LegacyRecording: Equatable {
  case notRecorded
  case recorded
}

/// What StoreKit 2 reported, read outside the store and handed to
/// ``ObserverModeAction/transactionsFetched(_:handledBeforeFetch:)``.
struct StoreKitTransactions: Equatable {
  /// Every transaction StoreKit has.
  var ids: Set<UInt64>
  /// The most recent verified transaction, if there is one.
  var latest: ObservedTransaction?
}

/// The parts of a StoreKit 2 transaction that observer mode acts on.
struct ObservedTransaction: Equatable {
  let id: UInt64
  let productId: String
  /// Whether the transaction is a new purchase, rather than a renewal.
  let isPurchase: Bool
  /// Whether the purchase started an offer, such as a free trial.
  let startedOffer: Bool
}

/// The events that change ``ObserverModeState``.
enum ObserverModeUpdate: Reducer {
  /// The app started a StoreKit 1 purchase of the product.
  case purchasingStarted(productId: String)
  /// StoreKit removed these products' transactions from the payment queue.
  case leftPaymentQueue(productIds: Set<String>)
  /// These StoreKit 2 transactions have been handled.
  case transactionsHandled(Set<UInt64>)
  /// StoreKit no longer has these transactions, for example because they
  /// were deleted in Xcode.
  case transactionsDisappeared(Set<UInt64>)
  /// These are the transactions made before observer mode was turned on.
  case legacyTransactionsRecorded(Set<UInt64>)

  func reduce(_ state: ObserverModeState) -> ObserverModeState {
    var state = state
    switch self {
    case .purchasingStarted(let productId):
      state.purchasingProductIds.insert(productId)
    case .leftPaymentQueue(let productIds):
      state.purchasingProductIds.subtract(productIds)
    case .transactionsHandled(let ids):
      state.handledTransactionIds.formUnion(ids)
    case .transactionsDisappeared(let ids):
      state.handledTransactionIds.subtract(ids)
    case .legacyTransactionsRecorded(let ids):
      state.handledTransactionIds.formUnion(ids)
      state.legacyRecording = .recorded
    }
    return state
  }
}

/// Everything observer mode's actions read or cause outside the store.
/// ``ObserverModeTracker`` provides it in the SDK, and tests provide a fake
/// that records the calls.
protocol ObserverModeContext: AnyObject {
  var store: ObserverModeStore { get }

  /// Whether the app asked the SDK to observe purchases.
  var observesPurchases: Bool { get }

  /// Whether a purchase is in progress, made through Superwall or already
  /// being observed. Read with the store locked, so it must not wait.
  var isPurchaseInProgress: Bool { get }

  /// Reads StoreKit 2's transactions. Called from the task lane, never from
  /// an action.
  func fetchTransactions() async -> StoreKitTransactions

  /// Saves the state. Called with the store locked, so the saves happen in
  /// the order of the changes; it only hands the write to storage's
  /// background queue.
  func save(_ state: ObserverModeState)

  /// Looks up the product and follows the StoreKit 1 purchase until it
  /// finishes. Queues the work on the task lane.
  func startObserving(productId: String)

  /// Tracks a StoreKit 2 purchase the app made itself. Queues the work on
  /// the task lane.
  func trackObservedPurchase(_ transaction: ObservedTransaction)
}

/// What an ``ObserverModeAction`` did.
enum ObserverModeOutcome: Equatable {
  /// Nothing needed doing.
  case unchanged
  /// The state changed, and nothing else started.
  case updated
  /// A StoreKit 1 purchase is now being observed.
  case startedObserving
  /// A StoreKit 2 purchase was handled and is being tracked.
  case tracked
}

/// The only ways observer mode changes. Each checks the state and changes it
/// in one locked step, so two threads can't both act on the same purchase,
/// and starts any follow-up once the store is unlocked.
enum ObserverModeAction: StoreAction {
  /// StoreKit 1 reported that the app started purchasing the product.
  case sk1PurchaseStarted(productId: String)
  /// StoreKit 1 removed these products' transactions from the payment queue.
  case sk1TransactionsLeftQueue(productIds: Set<String>)
  /// A purchase made through Superwall finished with these transactions.
  case sdkPurchaseCompleted(transactionIds: Set<UInt64>)
  /// The transactions StoreKit had when observer mode was first turned on.
  case legacyTransactionsFetched(Set<UInt64>)
  /// StoreKit 2's transactions were read. `handledBeforeFetch` is what was
  /// handled when the read started: only those can be proved gone by it.
  case transactionsFetched(StoreKitTransactions, handledBeforeFetch: Set<UInt64>)

  @discardableResult
  func execute(in context: ObserverModeContext) -> ObserverModeOutcome {
    let store = context.store
    let state = store.state

    func apply(_ update: ObserverModeUpdate) {
      store.update(update)
      context.save(store.state)
    }

    switch self {
    case .sk1PurchaseStarted(let productId):
      if state.purchasingProductIds.contains(productId) {
        return .unchanged
      }
      apply(.purchasingStarted(productId: productId))
      store.deferUntilUnlocked {
        context.startObserving(productId: productId)
      }
      return .startedObserving

    case .sk1TransactionsLeftQueue(let productIds):
      if state.purchasingProductIds.isDisjoint(with: productIds) {
        return .unchanged
      }
      apply(.leftPaymentQueue(productIds: productIds))
      return .updated

    case .sdkPurchaseCompleted(let ids):
      if !context.observesPurchases || ids.isSubset(of: state.handledTransactionIds) {
        return .unchanged
      }
      apply(.transactionsHandled(ids))
      return .updated

    case .legacyTransactionsFetched(let ids):
      if state.legacyRecording == .recorded {
        return .unchanged
      }
      apply(.legacyTransactionsRecorded(ids))
      return .updated

    case let .transactionsFetched(transactions, handledBeforeFetch):
      if transactions.ids.isEmpty {
        let gone = handledBeforeFetch.intersection(state.handledTransactionIds)
        if gone.isEmpty {
          return .unchanged
        }
        apply(.transactionsDisappeared(gone))
        return .updated
      }
      guard let latest = transactions.latest else {
        return .unchanged
      }
      // A purchase that started while StoreKit was being read is tracked by
      // its own flow.
      if context.isPurchaseInProgress || state.handledTransactionIds.contains(latest.id) {
        return .unchanged
      }
      apply(.transactionsHandled(transactions.ids))
      if !latest.isPurchase {
        return .updated
      }
      store.deferUntilUnlocked {
        context.trackObservedPurchase(latest)
      }
      return .tracked
    }
  }
}

extension ObserverModeContext {
  /// Records the transactions made before observer mode was turned on, the
  /// first time it's on. A step on the task lane.
  func recordLegacyTransactions() async {
    if store.state.legacyRecording == .recorded {
      return
    }
    let transactions = await fetchTransactions()
    store.dispatch(ObserverModeAction.legacyTransactionsFetched(transactions.ids), in: self)
  }

  /// Tracks the latest StoreKit 2 purchase if the app made it itself and it
  /// hasn't been handled yet. A step on the task lane.
  func detectUnobservedPurchase() async {
    let state = store.state
    if state.legacyRecording == .notRecorded {
      return
    }
    if isPurchaseInProgress {
      return
    }
    let transactions = await fetchTransactions()
    store.dispatch(
      ObserverModeAction.transactionsFetched(
        transactions,
        handledBeforeFetch: state.handledTransactionIds
      ),
      in: self
    )
  }
}
