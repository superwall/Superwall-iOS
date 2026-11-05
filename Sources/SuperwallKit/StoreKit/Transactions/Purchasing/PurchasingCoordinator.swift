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
/// The state lives in a ``StateStore``, so reads and changes are synchronous
/// and safe from any thread. Nothing here waits with the store locked:
/// looking up transactions and calling a purchase's completion happen once
/// it's unlocked.
final class PurchasingCoordinator: PurchaseContext, @unchecked Sendable {
  let store = PurchaseStore(initial: PurchaseState())
  private let factory: StoreTransactionFactory

  init(factory: StoreTransactionFactory) {
    self.factory = factory
  }

  /// The purchase in progress.
  var purchase: InFlightPurchase? {
    store.state.purchase
  }

  var source: PurchaseSource? {
    purchase?.source
  }

  var product: StoreProduct? {
    purchase?.product
  }

  var purchaseDate: Date? {
    purchase?.purchaseDate
  }

  var isFreeTrialAvailable: Bool {
    purchase?.isFreeTrialAvailable ?? false
  }

  /// Whether the purchase is a custom store checkout that the paywall runs itself.
  var isCustomStoreCheckout: Bool {
    purchase?.isCustomStoreCheckout ?? false
  }

  var lastInternalTransaction: StoreTransaction? {
    store.state.lastInternalTransaction
  }

  var transactions: [String: StoreTransaction] {
    store.state.transactionsByProductId
  }

  func setIsFreeTrialAvailable(to newValue: Bool) {
    store.update(PurchaseUpdate.isFreeTrialAvailable(newValue))
  }

  func setCompletion(_ completion: @escaping (PurchaseResult) -> Void) {
    store.update(PurchaseUpdate.completion(completion))
  }

  func beginPurchase(
    of product: StoreProduct,
    source: PurchaseSource,
    isFreeTrialAvailable: Bool,
    isCustomStoreCheckout: Bool = false
  ) {
    let purchase = InFlightPurchase(
      product: product,
      source: source,
      purchaseDate: Date(),
      isFreeTrialAvailable: isFreeTrialAvailable,
      isCustomStoreCheckout: isCustomStoreCheckout
    )
    store.update(PurchaseUpdate.begin(purchase))
  }

  /// Takes the purchase in progress out of the coordinator, leaving it free.
  func setAsidePurchase() -> SetAsidePurchase {
    let taken = Taken<SetAsidePurchase>()
    store.dispatch(PurchaseAction.setAside(taken), in: self)
    return taken.value ?? SetAsidePurchase(purchase: nil, completion: nil)
  }

  /// Puts back a purchase that was set aside, unless another purchase began meanwhile.
  func restore(_ purchase: SetAsidePurchase) {
    store.update(PurchaseUpdate.putBack(purchase))
  }

  /// Replaces the source of the purchase in progress, keeping when it started.
  func setSource(_ source: PurchaseSource) {
    store.update(PurchaseUpdate.source(source))
  }

  /// Gets the latest transaction of a specified product ID. Used with purchases, including when a purchase has
  /// resulted in a restore.
  func getLatestTransaction(
    forProductId productId: String,
    factory: StoreTransactionFactory
  ) async -> StoreTransaction? {
    // Get the date a purchase was initiated. This can never be nil after
    // a purchase.
    guard let purchaseDate = purchaseDate else {
      return nil
    }

    func getLatestSK2Transaction() async -> StoreTransaction? {
      // Try and get the latest transaction using SK2.
      if let verificationResult = await Transaction.latest(
        for: productId,
        since: purchaseDate
      ) {
        // Skip verification step as this has already been done.
        let transaction = verificationResult.unsafePayloadValue
        return await factory.makeStoreTransaction(from: transaction)
      }
      return nil
    }

    func getCurrentEntitlementTransaction() async -> StoreTransaction? {
      if let verificationResult = await Transaction.currentEntitlement(
        for: productId,
        since: purchaseDate
      ) {
        let transaction = verificationResult.unsafePayloadValue
        return await factory.makeStoreTransaction(from: transaction)
      }
      return nil
    }

    if let transaction = await getLatestSK2Transaction() {
      return transaction
    }

    // If no transaction retrieved, try to get last transaction if
    // the SDK handled purchasing.
    if let transaction = takeLastInternalTransaction() {
      return transaction
    }

    func getLastExternalStoreTransaction() -> StoreTransaction? {
      if let transaction = transactions[productId],
        transaction.transactionDate?.isWithinAnHourBefore(purchaseDate) == true {
        return transaction
      }
      return nil
    }

    // Otherwise get the last externally purchased
    // transaction from the payment queue. This won't work
    // with a purchase that results in a restore. That
    // should be caught by the above  instead.
    if let transaction = getLastExternalStoreTransaction() {
      return transaction
    }

    if let transaction = await getCurrentEntitlementTransaction() {
      return transaction
    }

    // If still no transaction, wait 500ms and try again before returning nil.
    try? await Task.sleep(nanoseconds: 500_000_000)

    if let transaction = getLastExternalStoreTransaction() {
      return transaction
    }

    if let transaction = await getLatestSK2Transaction() {
      return transaction
    }

    // Retry currentEntitlement after the delay,
    // as the crossgrade transaction may have settled.
    if let transaction = await getCurrentEntitlementTransaction() {
      return transaction
    }

    return nil
  }

  private func takeLastInternalTransaction() -> StoreTransaction? {
    let taken = Taken<StoreTransaction>()
    store.dispatch(PurchaseAction.takeLastInternalTransaction(taken), in: self)
    return taken.value
  }

  /// Stores the transaction and, if the purchase in progress is of its product,
  /// calls the purchase's completion with `result`, once.
  func completePurchase(
    of transaction: SK1Transaction,
    result: PurchaseResult
  ) async {
    let productId = transaction.payment.productIdentifier
    // Only complete if the product ID of the transaction is the same as
    // the purchasing transaction.
    guard product?.productIdentifier == productId else {
      return
    }
    let transaction = await factory.makeStoreTransaction(from: transaction)
    store.update(PurchaseUpdate.transaction(transaction, result: result))

    // The purchase may have changed while the transaction was made, so the
    // product is checked again as the completion is taken.
    let taken = Taken<(PurchaseResult) -> Void>()
    store.dispatch(PurchaseAction.takeCompletion(productId: productId, taken), in: self)
    taken.value?(result)
  }

  func storeTransaction(
    _ transaction: SK2Transaction,
    result: PurchaseResult
  ) async {
    let transaction = await factory.makeStoreTransaction(from: transaction)
    store.update(PurchaseUpdate.transaction(transaction, result: result))
  }

  func reset() {
    store.update(PurchaseUpdate.finish)
  }
}
