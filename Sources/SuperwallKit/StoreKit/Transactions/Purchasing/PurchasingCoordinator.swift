//
//  File.swift
//
//
//  Created by Yusuf Tör on 14/09/2023.
//

import Foundation
import StoreKit

/// Holds the purchase flow's state: the purchase in progress and the
/// transactions the SDK's purchasers got back.
///
/// The state lives in a ``StateStore`` and changes only through
/// ``PurchaseAction``s, so reads and changes are synchronous and safe from any
/// thread. Nothing waits with the store locked: transaction lookups happen
/// outside it, and a StoreKit 1 result is handed over once it's unlocked.
final class PurchasingCoordinator: @unchecked Sendable {
  let context: PurchaseContext

  var store: PurchaseStore {
    context.store
  }

  init(context: PurchaseContext) {
    self.context = context
  }

  convenience init(factory: StoreTransactionFactory) {
    self.init(context: StoreKitPurchaseContext(factory: factory))
  }

  /// The purchase in progress, read in one go.
  var purchase: InFlightPurchase? {
    store.read { $0.purchase }
  }

  /// Whether a purchase is in progress, including a StoreKit 1 purchase
  /// waiting for its result without one having begun. Reads the store
  /// without waiting on anything.
  var hasPurchaseInProgress: Bool {
    store.read { $0.hasPurchaseInProgress }
  }

  var lastInternalTransaction: StoreTransaction? {
    store.read { $0.lastInternalTransaction }
  }

  var transactions: [String: StoreTransaction] {
    store.read { $0.transactionsByProductId }
  }

  /// Starts a purchase, replacing any in progress, and returns it.
  @discardableResult
  func beginPurchase(
    of product: StoreProduct,
    method: PurchaseMethod,
    isFreeTrialAvailable: Bool
  ) -> InFlightPurchase {
    let purchase = InFlightPurchase(
      id: UUID(),
      product: product,
      method: method,
      purchaseDate: Date(),
      isFreeTrialAvailable: isFreeTrialAvailable
    )
    store.dispatch(PurchaseAction.begin(purchase), in: context)
    return purchase
  }

  /// Starts a purchase through StoreKit or the purchase controller.
  @discardableResult
  func beginPurchase(
    of product: StoreProduct,
    source: PurchaseSource,
    isFreeTrialAvailable: Bool
  ) -> InFlightPurchase {
    return beginPurchase(
      of: product,
      method: .storeKit(source),
      isFreeTrialAvailable: isFreeTrialAvailable
    )
  }

  /// Records whether the custom store checkout in progress closes its paywall,
  /// now that it has ended, and returns it. Returns `nil` if no custom store
  /// checkout is in progress.
  func endCheckout(productId: String, shouldDismiss: Bool) -> InFlightPurchase? {
    let update = PurchaseUpdate.checkoutEnded(productId: productId, shouldDismiss: shouldDismiss)
    let before = store.dispatch(
      PurchaseAction.endCheckout(productId: productId, shouldDismiss: shouldDismiss),
      in: context
    )
    guard before.purchase?.isCustomStoreCheckout == true else {
      return nil
    }
    return update.reduce(before).purchase
  }

  /// Records whether the observed transaction of the purchase in progress
  /// started an offer.
  func observeOffer(_ hasOffer: Bool) {
    store.dispatch(PurchaseAction.observeOffer(hasOffer), in: context)
  }

  /// Waits for the StoreKit 1 result of the purchase in progress. A purchase
  /// already waiting is resumed as cancelled.
  func awaitResult(_ completion: @escaping PurchaseCompletion) {
    store.dispatch(PurchaseAction.awaitResult(completion), in: context)
  }

  /// Ends `purchase`, unless another purchase has begun since.
  func finish(_ purchase: InFlightPurchase) {
    store.dispatch(PurchaseAction.finish(id: purchase.id), in: context)
  }

  /// Takes the purchase in progress out of the coordinator, leaving it free.
  func setAsidePurchase() -> PurchasePhase {
    return store.dispatch(PurchaseAction.setAside, in: context).phase
  }

  /// Puts back a purchase that was set aside, unless another purchase began
  /// meanwhile.
  func putBack(_ phase: PurchasePhase) {
    store.dispatch(PurchaseAction.putBack(phase), in: context)
  }

  /// Ends everything in progress.
  func reset() {
    store.dispatch(PurchaseAction.clear, in: context)
  }

  /// Gets the latest transaction of `purchase`'s product. Used with purchases,
  /// including when a purchase has resulted in a restore.
  func getLatestTransaction(for purchase: InFlightPurchase) async -> StoreTransaction? {
    let productId = purchase.product.productIdentifier
    let purchaseDate = purchase.purchaseDate

    if let transaction = await context.latestTransaction(forProductId: productId, since: purchaseDate) {
      return transaction
    }

    // If no transaction retrieved, try to get last transaction if
    // the SDK handled purchasing.
    let before = store.dispatch(PurchaseAction.useLastInternalTransaction, in: context)
    if let transaction = before.lastInternalTransaction {
      return transaction
    }

    func lastExternalStoreTransaction() -> StoreTransaction? {
      guard
        let transaction = transactions[productId],
        transaction.transactionDate?.isWithinAnHourBefore(purchaseDate) == true
      else {
        return nil
      }
      return transaction
    }

    // Otherwise get the last externally purchased transaction from the
    // payment queue. This won't work with a purchase that results in a
    // restore. That should be caught by the above instead.
    if let transaction = lastExternalStoreTransaction() {
      return transaction
    }

    if let transaction = await context.currentEntitlementTransaction(
      forProductId: productId,
      since: purchaseDate
    ) {
      return transaction
    }

    // If still no transaction, wait and try again before returning nil.
    await context.waitBeforeRetrying()

    if let transaction = lastExternalStoreTransaction() {
      return transaction
    }

    if let transaction = await context.latestTransaction(forProductId: productId, since: purchaseDate) {
      return transaction
    }

    // Retry currentEntitlement after the delay, as the crossgrade
    // transaction may have settled.
    return await context.currentEntitlementTransaction(
      forProductId: productId,
      since: purchaseDate
    )
  }

  /// Stores the transaction and, if the purchase in progress is of its
  /// product, hands `result` to the StoreKit 1 purchase waiting for it, once.
  /// A transaction that arrives with nothing in progress, such as a renewal,
  /// is left alone.
  func completePurchase(
    of transaction: SK1Transaction,
    result: PurchaseResult
  ) async {
    let productId = transaction.payment.productIdentifier
    let phase = store.read { $0.phase }
    if case .idle = phase {
      return
    }
    // Only complete if the product ID of the transaction is the same as
    // the purchasing transaction.
    if let purchase = phase.purchase,
      purchase.product.productIdentifier != productId {
      return
    }
    let storeTransaction = await context.makeStoreTransaction(from: transaction)
    store.dispatch(PurchaseAction.receiveTransaction(storeTransaction, result: result), in: context)
    // The purchase may have changed while the transaction was made, so the
    // product is checked again as the result is handed over.
    store.dispatch(PurchaseAction.deliverResult(result, productId: productId), in: context)
  }

  func storeTransaction(
    _ transaction: SK2Transaction,
    result: PurchaseResult
  ) async {
    let storeTransaction = await context.makeStoreTransaction(from: transaction)
    store.dispatch(PurchaseAction.receiveTransaction(storeTransaction, result: result), in: context)
  }
}

/// The purchase flow's real side effects and StoreKit lookups.
final class StoreKitPurchaseContext: PurchaseContext {
  let store = PurchaseStore(initial: PurchaseState())
  private let factory: StoreTransactionFactory

  init(factory: StoreTransactionFactory) {
    self.factory = factory
  }

  func deliver(_ result: PurchaseResult, to completion: @escaping PurchaseCompletion) {
    completion(result)
  }

  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction {
    return await factory.makeStoreTransaction(from: transaction)
  }

  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction {
    return await factory.makeStoreTransaction(from: transaction)
  }

  func latestTransaction(forProductId productId: String, since date: Date) async -> StoreTransaction? {
    guard let verificationResult = await Transaction.latest(for: productId, since: date) else {
      return nil
    }
    // Skip verification step as this has already been done.
    return await factory.makeStoreTransaction(from: verificationResult.unsafePayloadValue)
  }

  func currentEntitlementTransaction(
    forProductId productId: String,
    since date: Date
  ) async -> StoreTransaction? {
    guard let verificationResult = await Transaction.currentEntitlement(for: productId, since: date) else {
      return nil
    }
    return await factory.makeStoreTransaction(from: verificationResult.unsafePayloadValue)
  }

  func waitBeforeRetrying() async {
    try? await Task.sleep(nanoseconds: 500_000_000)
  }
}
