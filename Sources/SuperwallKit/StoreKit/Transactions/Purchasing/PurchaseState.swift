//
//  PurchaseState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable function_body_length

import Foundation

typealias PurchaseStore = StateStore<PurchaseContext, PurchaseState>

/// Called once with the StoreKit 1 result of a purchase.
typealias PurchaseCompletion = (PurchaseResult) -> Void

/// Everything purchase actions cause outside the store, and the StoreKit
/// lookups the purchase flow makes. ``PurchasingCoordinator`` provides the
/// real one, and tests a fake that records the calls.
protocol PurchaseContext: AnyObject {
  var store: PurchaseStore { get }

  /// Hands `result` to the StoreKit 1 purchase waiting on `completion`.
  /// Called with the store unlocked.
  func deliver(_ result: PurchaseResult, to completion: @escaping PurchaseCompletion)

  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction

  /// The latest StoreKit 2 transaction of `productId` since `date`.
  func latestTransaction(forProductId productId: String, since date: Date) async -> StoreTransaction?

  /// The StoreKit 2 transaction that currently entitles the user to
  /// `productId`, if it's from after `date`.
  func currentEntitlementTransaction(
    forProductId productId: String,
    since date: Date
  ) async -> StoreTransaction?

  /// Waits before looking for a transaction again.
  func waitBeforeRetrying() async
}

/// What's being bought.
enum PurchaseMethod {
  /// A purchase through StoreKit or the app's purchase controller.
  case storeKit(PurchaseSource)
  #if canImport(WebKit)
  /// A custom store checkout that the paywall runs itself, for the slot with
  /// this `Product.cacheKey`.
  case customStoreCheckout(
    paywall: PaywallViewController,
    productId: String,
    shouldDismiss: Bool
  )
  #endif

  var source: PurchaseSource {
    switch self {
    case .storeKit(let source):
      return source
    #if canImport(WebKit)
    case let .customStoreCheckout(paywall, productId, shouldDismiss):
      return .internal(productId, paywall, shouldDismiss)
    #endif
    }
  }

  var isCustomStoreCheckout: Bool {
    switch self {
    case .storeKit:
      return false
    #if canImport(WebKit)
    case .customStoreCheckout:
      return true
    #endif
    }
  }
}

/// A purchase that has started and not yet been handled.
struct InFlightPurchase {
  /// Tells this purchase apart from one that starts after it.
  let id: UUID
  let product: StoreProduct
  var method: PurchaseMethod
  /// When the purchase started. Transactions older than this aren't its own.
  let purchaseDate: Date
  var isFreeTrialAvailable: Bool

  var source: PurchaseSource {
    method.source
  }

  var isCustomStoreCheckout: Bool {
    method.isCustomStoreCheckout
  }
}

/// Where the purchase flow is.
enum PurchasePhase {
  case idle
  /// A StoreKit 1 purchase is waiting for its result, without a purchase
  /// having begun, such as when a purchase controller calls the SDK's
  /// purchaser itself.
  case awaitingResult(productId: String, completion: PurchaseCompletion)
  /// A purchase is in progress, and a StoreKit 1 purchase may be waiting for
  /// its result.
  case inFlight(InFlightPurchase, completion: PurchaseCompletion?)

  var purchase: InFlightPurchase? {
    if case let .inFlight(purchase, _) = self {
      return purchase
    }
    return nil
  }

  /// The product whose StoreKit 1 result is awaited or being bought.
  var productId: String? {
    switch self {
    case .idle:
      return nil
    case .awaitingResult(let productId, _):
      return productId
    case .inFlight(let purchase, _):
      return purchase.product.productIdentifier
    }
  }

  var completion: PurchaseCompletion? {
    switch self {
    case .idle:
      return nil
    case .awaitingResult(_, let completion):
      return completion
    case .inFlight(_, let completion):
      return completion
    }
  }
}

/// The purchase flow's state, held by ``PurchasingCoordinator``. Changed
/// only by ``PurchaseUpdate`` reducers.
struct PurchaseState {
  var phase: PurchasePhase = .idle
  /// A purchase taken out of the way while a custom store checkout from
  /// another paywall completes. It comes back afterwards unless it finished
  /// meanwhile.
  var setAsidePhase: PurchasePhase = .idle
  /// The latest purchased transaction of each product, for when StoreKit 2
  /// can't find it.
  var transactionsByProductId: [String: StoreTransaction] = [:]
  /// The last transaction the SDK's own purchasers got back.
  var lastInternalTransaction: StoreTransaction?

  var purchase: InFlightPurchase? {
    phase.purchase
  }

  var hasPurchaseInProgress: Bool {
    if case .idle = phase {
      return false
    }
    return true
  }
}

/// The ways ``PurchaseState`` can change. A completion that one of these
/// leaves out of the phase is resumed by the action that applied it.
enum PurchaseUpdate: Reducer {
  /// A purchase began. A StoreKit 1 result that was waiting without a
  /// purchase now belongs to it; one waiting for an earlier purchase is
  /// dropped.
  case began(InFlightPurchase)
  /// A custom store checkout ended, so it's known whether it closes the
  /// paywall, for the slot with this `Product.cacheKey`.
  case checkoutEnded(productId: String, shouldDismiss: Bool)
  /// Observer mode saw the purchase's transaction, which shows whether it
  /// started an offer.
  case offerObserved(Bool)
  /// A StoreKit 1 purchase of the product with this id started waiting for
  /// its result, dropping any other that was waiting.
  case resultAwaited(productId: String, completion: PurchaseCompletion)
  /// The StoreKit 1 result was handed to whoever was waiting for it.
  case resultDelivered
  /// The purchase with this id was handled, whether it's in progress or set
  /// aside. Does nothing to another one.
  case finished(id: UUID)
  /// The phase was set aside while another purchase is handled.
  case setAside
  /// The phase that was set aside comes back, unless another purchase began
  /// meanwhile.
  case putBack
  /// Ends everything in progress.
  case cleared
  /// A purchaser got a transaction back.
  case transactionReceived(StoreTransaction, result: PurchaseResult)
  /// The last internal transaction was used for a purchase.
  case lastInternalTransactionUsed

  func reduce(_ state: PurchaseState) -> PurchaseState {
    var state = state
    switch self {
    case .began(let purchase):
      if case .awaitingResult(_, let completion) = state.phase {
        state.phase = .inFlight(purchase, completion: completion)
      } else {
        state.phase = .inFlight(purchase, completion: nil)
      }
    case let .checkoutEnded(productId, shouldDismiss):
      #if canImport(WebKit)
      guard
        case .inFlight(var purchase, let completion) = state.phase,
        case let .customStoreCheckout(paywall, _, _) = purchase.method
      else {
        return state
      }
      purchase.method = .customStoreCheckout(
        paywall: paywall,
        productId: productId,
        shouldDismiss: shouldDismiss
      )
      state.phase = .inFlight(purchase, completion: completion)
      #endif
    case .offerObserved(let hasOffer):
      guard case .inFlight(var purchase, let completion) = state.phase else {
        return state
      }
      purchase.isFreeTrialAvailable = hasOffer
      state.phase = .inFlight(purchase, completion: completion)
    case let .resultAwaited(productId, completion):
      if case .inFlight(let purchase, _) = state.phase {
        state.phase = .inFlight(purchase, completion: completion)
      } else {
        state.phase = .awaitingResult(productId: productId, completion: completion)
      }
    case .resultDelivered:
      switch state.phase {
      case .idle:
        break
      case .awaitingResult:
        state.phase = .idle
      case .inFlight(let purchase, _):
        state.phase = .inFlight(purchase, completion: nil)
      }
    case .finished(let id):
      if state.purchase?.id == id {
        state.phase = .idle
      }
      if state.setAsidePhase.purchase?.id == id {
        state.setAsidePhase = .idle
      }
    case .setAside:
      state.setAsidePhase = state.phase
      state.phase = .idle
    case .putBack:
      if case .idle = state.phase {
        state.phase = state.setAsidePhase
      }
      state.setAsidePhase = .idle
    case .cleared:
      state.phase = .idle
      state.setAsidePhase = .idle
    case let .transactionReceived(transaction, result):
      if result == .purchased {
        state.transactionsByProductId = Self.keepingLatest(
          transaction,
          in: state.transactionsByProductId
        )
      }
      state.lastInternalTransaction = transaction
    case .lastInternalTransactionUsed:
      state.lastInternalTransaction = nil
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

/// Every change to the purchase flow. Each one returns the state it saw
/// before changing it, read in the same locked step.
///
/// A completion that a change leaves out of the phase without its result is
/// resumed as cancelled, once the store is unlocked, so a StoreKit 1 purchase
/// never waits forever.
enum PurchaseAction: StoreAction {
  case begin(InFlightPurchase)
  case endCheckout(productId: String, shouldDismiss: Bool)
  case observeOffer(Bool)
  case awaitResult(productId: String, completion: PurchaseCompletion)
  /// Hands `result` to the StoreKit 1 purchase waiting for it, if it's of
  /// `productId`.
  case deliverResult(PurchaseResult, productId: String)
  case finish(id: UUID)
  case setAside
  case putBack
  case clear
  case receiveTransaction(StoreTransaction, result: PurchaseResult)
  case useLastInternalTransaction

  func execute(in context: PurchaseContext) -> PurchaseState {
    let store = context.store
    let before = store.state
    var dropped: [PurchaseCompletion] = []
    switch self {
    case .begin(let purchase):
      if case .inFlight(_, let completion?) = before.phase {
        dropped.append(completion)
      }
      store.update(PurchaseUpdate.began(purchase))
    case let .endCheckout(productId, shouldDismiss):
      store.update(PurchaseUpdate.checkoutEnded(productId: productId, shouldDismiss: shouldDismiss))
    case .observeOffer(let hasOffer):
      store.update(PurchaseUpdate.offerObserved(hasOffer))
    case let .awaitResult(productId, completion):
      dropped += [before.phase.completion].compactMap { $0 }
      store.update(PurchaseUpdate.resultAwaited(productId: productId, completion: completion))
    case let .deliverResult(result, productId):
      guard
        before.phase.productId == productId,
        let completion = before.phase.completion
      else {
        return before
      }
      store.update(PurchaseUpdate.resultDelivered)
      store.deferUntilUnlocked {
        context.deliver(result, to: completion)
      }
    case .finish(let id):
      if before.purchase?.id == id {
        dropped += [before.phase.completion].compactMap { $0 }
      }
      if before.setAsidePhase.purchase?.id == id {
        dropped += [before.setAsidePhase.completion].compactMap { $0 }
      }
      store.update(PurchaseUpdate.finished(id: id))
    case .setAside:
      // Only one purchase is set aside at a time, so an earlier one is over.
      dropped += [before.setAsidePhase.completion].compactMap { $0 }
      store.update(PurchaseUpdate.setAside)
    case .putBack:
      if before.hasPurchaseInProgress {
        // Another purchase began meanwhile, so the one set aside is over.
        dropped += [before.setAsidePhase.completion].compactMap { $0 }
      }
      store.update(PurchaseUpdate.putBack)
    case .clear:
      dropped += [before.phase.completion, before.setAsidePhase.completion].compactMap { $0 }
      store.update(PurchaseUpdate.cleared)
    case let .receiveTransaction(transaction, result):
      store.update(PurchaseUpdate.transactionReceived(transaction, result: result))
    case .useLastInternalTransaction:
      store.update(PurchaseUpdate.lastInternalTransactionUsed)
    }
    for completion in dropped {
      store.deferUntilUnlocked {
        context.deliver(.cancelled, to: completion)
      }
    }
    return before
  }
}
