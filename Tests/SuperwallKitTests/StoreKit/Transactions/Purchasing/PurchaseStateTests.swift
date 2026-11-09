//
//  PurchaseStateTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

import Foundation
import StoreKit
import Testing
@testable import SuperwallKit

/// An SK1 transaction of `productId`, with a date.
private final class FakeSK1Transaction: SKPaymentTransaction, @unchecked Sendable {
  private let fakePayment: SKMutablePayment
  private let fakeState: SKPaymentTransactionState
  private let fakeDate: Date?

  init(productId: String, state: SKPaymentTransactionState = .purchased, date: Date? = Date()) {
    let payment = SKMutablePayment()
    payment.productIdentifier = productId
    fakePayment = payment
    fakeState = state
    fakeDate = date
    super.init()
  }

  override var payment: SKPayment { fakePayment }
  override var transactionState: SKPaymentTransactionState { fakeState }
  override var transactionDate: Date? { fakeDate }
  override var transactionIdentifier: String? { "id" }
}

private func storeTransaction(from transaction: SK1Transaction) -> StoreTransaction {
  return StoreTransaction(
    transaction: SK1StoreTransaction(transaction: transaction),
    configRequestId: "",
    appSessionId: ""
  )
}

/// Records every result it hands over, and finds no StoreKit 2 transactions.
private final class FakePurchaseContext: PurchaseContext, @unchecked Sendable {
  let store = PurchaseStore(initial: PurchaseState())
  private let lock = NSLock()
  private var delivered: [PurchaseResult] = []
  /// Runs while a result is handed over.
  var onDeliver: (() -> Void)?

  var deliveredResults: [PurchaseResult] {
    lock.lock()
    defer { lock.unlock() }
    return delivered
  }

  func deliver(_ result: PurchaseResult, to completion: @escaping PurchaseCompletion) {
    lock.lock()
    delivered.append(result)
    lock.unlock()
    onDeliver?()
    completion(result)
  }

  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction {
    return storeTransaction(from: transaction)
  }

  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction {
    fatalError("Not used")
  }

  func latestTransaction(forProductId productId: String, since date: Date) async -> StoreTransaction? {
    return nil
  }

  func currentEntitlementTransaction(forProductId productId: String, since date: Date) async -> StoreTransaction? {
    return nil
  }

  func waitBeforeRetrying() async {}
}

private func makeProduct(_ id: String = "product") -> StoreProduct {
  return StoreProduct(sk1Product: MockSkProduct(productIdentifier: id))
}

private func makePurchase(_ id: String = "product") -> InFlightPurchase {
  let product = makeProduct(id)
  return InFlightPurchase(
    id: UUID(),
    product: product,
    method: .storeKit(.purchaseFunc(product)),
    purchaseDate: Date(),
    isFreeTrialAvailable: false
  )
}

private func makeTransaction(
  _ id: String = "product",
  state: SKPaymentTransactionState = .purchased,
  date: Date? = Date()
) -> StoreTransaction {
  return storeTransaction(from: FakeSK1Transaction(productId: id, state: state, date: date))
}

private func inFlight(_ purchase: InFlightPurchase, completion: PurchaseCompletion? = nil) -> PurchaseState {
  var state = PurchaseState()
  state.phase = .inFlight(purchase, completion: completion)
  return state
}

private func awaiting(_ completion: @escaping PurchaseCompletion) -> PurchaseState {
  var state = PurchaseState()
  state.phase = .awaitingResult(completion)
  return state
}

private func isIdle(_ state: PurchaseState) -> Bool {
  if case .idle = state.phase {
    return true
  }
  return false
}

private func isAwaiting(_ state: PurchaseState) -> Bool {
  if case .awaitingResult = state.phase {
    return true
  }
  return false
}

@Suite("PurchaseUpdate reducers")
struct PurchaseUpdateTests {
  @Test("began starts a purchase from idle")
  func beganFromIdle() {
    let purchase = makePurchase()
    let state = PurchaseUpdate.began(purchase).reduce(PurchaseState())
    #expect(state.purchase?.id == purchase.id)
    #expect(state.phase.completion == nil)
  }

  @Test("began keeps a StoreKit 1 result that was waiting without a purchase")
  func beganWhileAwaiting() {
    let state = PurchaseUpdate.began(makePurchase()).reduce(awaiting { _ in })
    #expect(state.purchase != nil)
    #expect(state.phase.completion != nil)
  }

  @Test("began drops the completion of the purchase it replaces")
  func beganWhileInFlight() {
    let second = makePurchase("second")
    let state = PurchaseUpdate.began(second).reduce(inFlight(makePurchase("first")) { _ in })
    #expect(state.purchase?.id == second.id)
    #expect(state.phase.completion == nil)
  }

  @Test("checkoutEnded leaves a StoreKit purchase alone")
  func checkoutEndedOnStoreKitPurchase() {
    let purchase = makePurchase()
    let state = PurchaseUpdate.checkoutEnded(productId: "other", shouldDismiss: true).reduce(inFlight(purchase))
    #expect(state.purchase?.isCustomStoreCheckout == false)
    guard case .purchaseFunc = state.purchase?.source else {
      Issue.record("Expected the source to stay the same")
      return
    }
  }

  @Test("offerObserved changes the purchase in progress only")
  func offerObserved() {
    #expect(isIdle(PurchaseUpdate.offerObserved(true).reduce(PurchaseState())))
    let purchase = makePurchase()
    let state = PurchaseUpdate.offerObserved(true).reduce(inFlight(purchase) { _ in })
    #expect(state.purchase?.isFreeTrialAvailable == true)
    #expect(state.purchase?.purchaseDate == purchase.purchaseDate)
    #expect(state.phase.completion != nil)
  }

  @Test("resultAwaited waits without a purchase, or for the one in progress")
  func resultAwaited() {
    #expect(isAwaiting(PurchaseUpdate.resultAwaited { _ in }.reduce(PurchaseState())))
    let purchase = makePurchase()
    let state = PurchaseUpdate.resultAwaited { _ in }.reduce(inFlight(purchase))
    #expect(state.purchase?.id == purchase.id)
    #expect(state.phase.completion != nil)
  }

  @Test("resultDelivered stops waiting and keeps the purchase")
  func resultDelivered() {
    #expect(isIdle(PurchaseUpdate.resultDelivered.reduce(awaiting { _ in })))
    #expect(isIdle(PurchaseUpdate.resultDelivered.reduce(PurchaseState())))
    let purchase = makePurchase()
    let state = PurchaseUpdate.resultDelivered.reduce(inFlight(purchase) { _ in })
    #expect(state.purchase?.id == purchase.id)
    #expect(state.phase.completion == nil)
  }

  @Test("finished ends only the purchase with that id")
  func finished() {
    let purchase = makePurchase()
    #expect(isIdle(PurchaseUpdate.finished(id: purchase.id).reduce(inFlight(purchase) { _ in })))
    let other = PurchaseUpdate.finished(id: UUID()).reduce(inFlight(purchase))
    #expect(other.purchase?.id == purchase.id)
    #expect(isAwaiting(PurchaseUpdate.finished(id: purchase.id).reduce(awaiting { _ in })))
  }

  @Test("setAside and cleared leave the flow idle")
  func setAsideAndCleared() {
    #expect(isIdle(PurchaseUpdate.setAside.reduce(inFlight(makePurchase()) { _ in })))
    #expect(isIdle(PurchaseUpdate.cleared.reduce(awaiting { _ in })))
  }

  @Test("putBack restores a phase only if the flow is idle")
  func putBack() {
    let first = makePurchase("first")
    let setAside = PurchasePhase.inFlight(first, completion: nil)
    #expect(PurchaseUpdate.putBack(setAside).reduce(PurchaseState()).purchase?.id == first.id)

    let second = makePurchase("second")
    #expect(PurchaseUpdate.putBack(setAside).reduce(inFlight(second)).purchase?.id == second.id)
  }

  @Test("a purchased transaction is kept per product unless an older one arrives")
  func keepsLatestTransaction() {
    let now = Date()
    let newer = makeTransaction(date: now)
    let older = makeTransaction(date: now.addingTimeInterval(-60))

    var state = PurchaseUpdate.transactionReceived(newer, result: .purchased).reduce(PurchaseState())
    state = PurchaseUpdate.transactionReceived(older, result: .purchased).reduce(state)
    #expect(state.transactionsByProductId["product"]?.transactionDate == now)
    #expect(state.lastInternalTransaction?.transactionDate == older.transactionDate)
  }

  @Test("a transaction that isn't purchased is only the last internal one")
  func failedTransaction() {
    let failed = makeTransaction(state: .failed)
    let state = PurchaseUpdate.transactionReceived(failed, result: .cancelled).reduce(PurchaseState())
    #expect(state.transactionsByProductId.isEmpty)
    #expect(state.lastInternalTransaction != nil)
    #expect(PurchaseUpdate.lastInternalTransactionUsed.reduce(state).lastInternalTransaction == nil)
  }
}

@Suite("PurchasingCoordinator")
struct PurchasingCoordinatorTests {
  private func make() -> (PurchasingCoordinator, FakePurchaseContext) {
    let context = FakePurchaseContext()
    return (PurchasingCoordinator(context: context), context)
  }

  @Test("a purchase is in progress while it's in flight or a StoreKit 1 result waits")
  func hasPurchaseInProgress() {
    let (coordinator, _) = make()
    #expect(!coordinator.hasPurchaseInProgress)

    coordinator.awaitResult { _ in }
    #expect(coordinator.hasPurchaseInProgress)
    coordinator.reset()
    #expect(!coordinator.hasPurchaseInProgress)

    let purchase = coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: false)
    #expect(coordinator.hasPurchaseInProgress)
    coordinator.finish(purchase)
    #expect(!coordinator.hasPurchaseInProgress)
  }

  @Test("beginning a purchase while a StoreKit 1 result waits keeps it waiting")
  func beginWhileResultWaits() {
    let (coordinator, context) = make()
    coordinator.awaitResult { _ in }
    let purchase = coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: false)

    #expect(coordinator.purchase?.id == purchase.id)
    #expect(coordinator.store.state.phase.completion != nil)
    #expect(context.deliveredResults.isEmpty)
  }

  @Test("beginning a purchase over one whose result waits cancels the old one")
  func beginOverWaitingPurchase() {
    let (coordinator, context) = make()
    coordinator.beginPurchase(of: makeProduct("first"), source: .purchaseFunc(makeProduct("first")), isFreeTrialAvailable: false)
    coordinator.awaitResult { _ in }
    coordinator.beginPurchase(of: makeProduct("second"), source: .purchaseFunc(makeProduct("second")), isFreeTrialAvailable: false)

    #expect(context.deliveredResults == [.cancelled])
    #expect(coordinator.store.state.phase.completion == nil)
  }

  @Test("a second StoreKit 1 purchase waiting for its result cancels the first, so it doesn't hang")
  func secondAwaitCancelsFirst() {
    let (coordinator, context) = make()
    var firstResult: PurchaseResult?
    coordinator.awaitResult { firstResult = $0 }
    coordinator.awaitResult { _ in }

    #expect(firstResult == .cancelled)
    #expect(context.deliveredResults == [.cancelled])
  }

  @Test("finishing a purchase whose StoreKit 1 result waits resumes it as cancelled")
  func finishWhileResultWaits() {
    let (coordinator, context) = make()
    let purchase = coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: false)
    var result: PurchaseResult?
    coordinator.awaitResult { result = $0 }

    coordinator.finish(purchase)

    #expect(result == .cancelled)
    #expect(coordinator.purchase == nil)
    #expect(context.deliveredResults == [.cancelled])
  }

  @Test("finishing an earlier purchase leaves the one in progress alone")
  func finishOtherPurchase() {
    let (coordinator, context) = make()
    let first = coordinator.beginPurchase(of: makeProduct("first"), source: .purchaseFunc(makeProduct("first")), isFreeTrialAvailable: false)
    let second = coordinator.beginPurchase(of: makeProduct("second"), source: .purchaseFunc(makeProduct("second")), isFreeTrialAvailable: false)
    coordinator.awaitResult { _ in }

    coordinator.finish(first)

    #expect(coordinator.purchase?.id == second.id)
    #expect(context.deliveredResults.isEmpty)
  }

  @Test("setting aside and putting back restores the purchase and its completion")
  func setAsideAndPutBack() {
    let (coordinator, context) = make()
    let purchase = coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: true)
    coordinator.awaitResult { _ in }

    let setAside = coordinator.setAsidePurchase()
    #expect(coordinator.purchase == nil)
    #expect(setAside.purchase?.id == purchase.id)
    #expect(setAside.completion != nil)

    coordinator.putBack(setAside)
    #expect(coordinator.purchase?.id == purchase.id)
    #expect(coordinator.store.state.phase.completion != nil)
    #expect(context.deliveredResults.isEmpty)
  }

  @Test("putting back after another purchase began cancels the set-aside completion")
  func putBackDropsCompletion() {
    let (coordinator, context) = make()
    coordinator.beginPurchase(of: makeProduct("first"), source: .purchaseFunc(makeProduct("first")), isFreeTrialAvailable: false)
    var result: PurchaseResult?
    coordinator.awaitResult { result = $0 }
    let setAside = coordinator.setAsidePurchase()
    let second = coordinator.beginPurchase(of: makeProduct("second"), source: .purchaseFunc(makeProduct("second")), isFreeTrialAvailable: false)

    coordinator.putBack(setAside)

    #expect(coordinator.purchase?.id == second.id)
    #expect(result == .cancelled)
    #expect(context.deliveredResults == [.cancelled])
  }

  @Test("a result is handed over only for a transaction of the product being bought")
  func resultMatchesProduct() async {
    let (coordinator, context) = make()
    coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: false)
    coordinator.awaitResult { _ in }

    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "other"), result: .purchased)
    #expect(context.deliveredResults.isEmpty)

    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)
    #expect(context.deliveredResults == [.purchased])
    #expect(coordinator.transactions["product"] != nil)
  }

  @Test("a result is handed over when no purchase began")
  func resultWithoutPurchase() async {
    let (coordinator, context) = make()
    coordinator.awaitResult { _ in }

    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .pending)

    #expect(context.deliveredResults == [.pending])
    #expect(isIdle(coordinator.store.state))
  }

  @Test("a transaction that arrives with nothing in progress isn't stored")
  func transactionWithNothingInProgress() async {
    let (coordinator, context) = make()

    // A renewal, or an Ask to Buy approval, arrives on its own.
    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)

    #expect(coordinator.lastInternalTransaction == nil)
    #expect(coordinator.transactions.isEmpty)
    #expect(context.deliveredResults.isEmpty)

    // And once a purchase has finished.
    let purchase = coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: false)
    coordinator.finish(purchase)
    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)
    #expect(coordinator.lastInternalTransaction == nil)
    #expect(coordinator.transactions.isEmpty)
  }

  @Test("200 concurrent results hand over the result once")
  func concurrentResults() async {
    let (coordinator, context) = make()
    coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: false)
    coordinator.awaitResult { _ in }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<200 {
        group.addTask {
          await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)
        }
      }
    }
    #expect(context.deliveredResults == [.purchased])
  }

  @Test("200 concurrent purchases leave one whole purchase")
  func concurrentBegins() async {
    let (coordinator, _) = make()
    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 {
        group.addTask {
          let product = makeProduct("product-\(index)")
          coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)
          coordinator.observeOffer(index.isMultiple(of: 2))
        }
      }
    }
    guard
      let purchase = coordinator.purchase,
      case .purchaseFunc(let sourceProduct) = purchase.source
    else {
      Issue.record("Expected a purchase from the purchase function")
      return
    }
    // The product and source always come from the same begin.
    #expect(sourceProduct === purchase.product)
  }

  @Test("the result is handed over with the store unlocked")
  func resultDeliveredUnlocked() async {
    let (coordinator, context) = make()
    coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: false)
    coordinator.awaitResult { _ in }
    var readOnOtherThread = false
    context.onDeliver = {
      // Another thread reads the store while the result is handed over. If
      // the store were locked, the read would wait until the timeout.
      let done = DispatchSemaphore(value: 0)
      Thread {
        _ = coordinator.purchase
        done.signal()
      }.start()
      readOnOtherThread = done.wait(timeout: .now() + 2) == .success
    }

    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)
    #expect(readOnOtherThread)
  }

  @Test("the last internal transaction is used once")
  func usesLastInternalTransaction() async {
    let (coordinator, _) = make()
    let purchase = coordinator.beginPurchase(of: makeProduct(), source: .purchaseFunc(makeProduct()), isFreeTrialAvailable: false)
    await coordinator.completePurchase(
      of: FakeSK1Transaction(productId: "product", state: .failed, date: nil),
      result: .cancelled
    )
    #expect(coordinator.lastInternalTransaction != nil)

    let first = await coordinator.getLatestTransaction(for: purchase)
    #expect(first != nil)
    #expect(coordinator.lastInternalTransaction == nil)
    #expect(await coordinator.getLatestTransaction(for: purchase) == nil)
  }
}

/// Records payments, and can report a result for each as soon as it's added.
private final class FakePaymentQueue: PaymentQueue, @unchecked Sendable {
  var onAdd: ((SKPayment) -> Void)?
  private let lock = NSLock()
  private var added: [SKPayment] = []

  var payments: [SKPayment] {
    lock.lock()
    defer { lock.unlock() }
    return added
  }

  func add(_ payment: SKPayment) {
    lock.lock()
    added.append(payment)
    lock.unlock()
    onAdd?(payment)
  }
}

@Suite("ProductPurchaserSK1 purchase")
struct ProductPurchaserSK1PurchaseTests {
  private func make(queue: FakePaymentQueue) -> (ProductPurchaserSK1, PurchasingCoordinator) {
    let dependencyContainer = DependencyContainer()
    let coordinator = PurchasingCoordinator(context: FakePurchaseContext())
    let purchaser = ProductPurchaserSK1(
      shouldFinishTransactions: false,
      storeKitManager: dependencyContainer.storeKitManager,
      receiptManager: dependencyContainer.receiptManager,
      identityManager: dependencyContainer.identityManager,
      coordinator: coordinator,
      storage: dependencyContainer.storage,
      factory: dependencyContainer,
      payments: queue
    )
    return (purchaser, coordinator)
  }

  @Test("a result reported as soon as the payment is queued is returned")
  func immediateResult() async {
    let queue = FakePaymentQueue()
    let (purchaser, coordinator) = make(queue: queue)
    let product = makeProduct()
    coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)

    var hadCompletionWhenQueued = false
    queue.onAdd = { payment in
      hadCompletionWhenQueued = coordinator.store.state.phase.completion != nil
      // The device refuses the payment straight away.
      Task {
        await coordinator.completePurchase(
          of: FakeSK1Transaction(productId: payment.productIdentifier, state: .failed),
          result: .cancelled
        )
      }
    }

    let result = await purchaser.purchase(product: product)

    #expect(result == .cancelled)
    #expect(hadCompletionWhenQueued)
    #expect(coordinator.store.state.phase.completion == nil)
  }

  @Test("the first of two overlapping purchases returns instead of waiting forever")
  func overlappingPurchases() async {
    let queue = FakePaymentQueue()
    let (purchaser, coordinator) = make(queue: queue)
    let product = makeProduct()
    coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)

    let first = Task { await purchaser.purchase(product: product) }
    while queue.payments.isEmpty {
      await Task.yield()
    }
    let second = Task { await purchaser.purchase(product: product) }
    while queue.payments.count < 2 {
      await Task.yield()
    }
    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)

    #expect(await first.value == .cancelled)
    #expect(await second.value == .purchased)
  }
}
