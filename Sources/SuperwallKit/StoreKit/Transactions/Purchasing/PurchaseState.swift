//
//  PurchaseState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

typealias PurchaseStore = StateStore<PurchaseContext, PurchaseState>

/// What purchase actions need. ``PurchasingCoordinator`` provides it.
protocol PurchaseContext: AnyObject {
  var store: PurchaseStore { get }
}

/// A purchase that has started and not yet been handled.
struct InFlightPurchase {
  let product: StoreProduct
  /// Where the purchase was started from. A custom store checkout's source
  /// can change once it completes, as only then is it known whether the
  /// purchase closes the paywall.
  var source: PurchaseSource
  /// When the purchase started. Transactions older than this aren't its own.
  let purchaseDate: Date
  var isFreeTrialAvailable: Bool
  /// Whether the purchase is a custom store checkout that the paywall runs
  /// itself.
  let isCustomStoreCheckout: Bool
}

/// The purchase flow's state, held by ``PurchasingCoordinator``. Changed
/// only by ``PurchaseUpdate`` reducers.
struct PurchaseState {
  /// The purchase in progress, if any.
  var purchase: InFlightPurchase?
  /// Called once with the StoreKit 1 result of the purchase in progress.
  ///
  /// Kept apart from ``purchase`` because a StoreKit 1 purchase sets it
  /// whether or not a purchase was begun, such as when a purchase controller
  /// calls the SDK's purchaser.
  var completion: ((PurchaseResult) -> Void)?
  /// The latest purchased transaction of each product, for when StoreKit 2
  /// can't find it.
  var transactionsByProductId: [String: StoreTransaction] = [:]
  /// The last transaction the SDK's own purchasers got back.
  var lastInternalTransaction: StoreTransaction?
}

/// A purchase in progress, set aside while another is handled.
struct SetAsidePurchase {
  let purchase: InFlightPurchase?
  let completion: ((PurchaseResult) -> Void)?
}

/// The ways ``PurchaseState`` can change.
enum PurchaseUpdate: Reducer {
  /// Starts `purchase`, replacing any purchase in progress.
  case begin(InFlightPurchase)
  /// Replaces the source of the purchase in progress, keeping when it began.
  case source(PurchaseSource)
  case isFreeTrialAvailable(Bool)
  case completion(((PurchaseResult) -> Void)?)
  /// Ends the purchase in progress.
  case finish
  /// Puts back a purchase that was set aside, unless another began meanwhile.
  case putBack(SetAsidePurchase)
  /// Records a transaction a purchaser got back.
  case transaction(StoreTransaction, result: PurchaseResult)
  case lastInternalTransaction(StoreTransaction?)

  func reduce(_ state: PurchaseState) -> PurchaseState {
    var state = state
    switch self {
    case .begin(let purchase):
      state.purchase = purchase
    case .source(let source):
      state.purchase?.source = source
    case .isFreeTrialAvailable(let isAvailable):
      state.purchase?.isFreeTrialAvailable = isAvailable
    case .completion(let completion):
      state.completion = completion
    case .finish:
      state.purchase = nil
      state.completion = nil
    case .putBack(let setAside):
      if state.purchase != nil {
        return state
      }
      state.purchase = setAside.purchase
      state.completion = setAside.completion
    case let .transaction(transaction, result):
      if result == .purchased {
        state.transactionsByProductId = Self.keepingLatest(
          transaction,
          in: state.transactionsByProductId
        )
      }
      state.lastInternalTransaction = transaction
    case .lastInternalTransaction(let transaction):
      state.lastInternalTransaction = transaction
    }
    return state
  }

  /// Stores `transaction` if it's purchased and newer than the one stored for
  /// its product.
  private static func keepingLatest(
    _ transaction: StoreTransaction,
    in transactions: [String: StoreTransaction]
  ) -> [String: StoreTransaction] {
    guard case .purchased = transaction.state else {
      return transactions
    }
    let productId = transaction.payment.productIdentifier
    var transactions = transactions
    if let existingDate = transactions[productId]?.transactionDate {
      if transaction.transactionDate?.compare(existingDate) == .orderedDescending {
        transactions[productId] = transaction
      }
    } else {
      transactions[productId] = transaction
    }
    return transactions
  }
}

/// Holds what an action takes out of the state, for its caller to read once
/// the action has run.
final class Taken<Value> {
  var value: Value?
}

/// Reads and changes ``PurchaseState`` in one step, so two threads can't both
/// take the same value.
enum PurchaseAction: StoreAction {
  /// Takes the purchase in progress out of the state, leaving it free.
  case setAside(Taken<SetAsidePurchase>)
  /// Takes the completion, if the purchase in progress is of `productId`.
  case takeCompletion(productId: String, Taken<(PurchaseResult) -> Void>)
  case takeLastInternalTransaction(Taken<StoreTransaction>)

  func execute(in context: PurchaseContext) {
    let store = context.store
    let state = store.state
    switch self {
    case .setAside(let taken):
      taken.value = SetAsidePurchase(
        purchase: state.purchase,
        completion: state.completion
      )
      store.update(PurchaseUpdate.finish)
    case let .takeCompletion(productId, taken):
      guard state.purchase?.product.productIdentifier == productId else {
        return
      }
      taken.value = state.completion
      store.update(PurchaseUpdate.completion(nil))
    case .takeLastInternalTransaction(let taken):
      taken.value = state.lastInternalTransaction
      store.update(PurchaseUpdate.lastInternalTransaction(nil))
    }
  }
}
