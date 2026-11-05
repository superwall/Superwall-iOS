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

private final class FakeStoreTransactionFactory: StoreTransactionFactory {
  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction {
    return Self.make(transaction)
  }

  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction {
    fatalError("Not used")
  }

  func makeStoreTransaction(from transaction: CustomStoreTransaction) async -> StoreTransaction {
    fatalError("Not used")
  }

  static func make(_ transaction: SK1Transaction) -> StoreTransaction {
    return StoreTransaction(
      transaction: SK1StoreTransaction(transaction: transaction),
      configRequestId: "",
      appSessionId: ""
    )
  }
}

private func makeProduct(_ id: String = "product") -> StoreProduct {
  return StoreProduct(sk1Product: MockSkProduct(productIdentifier: id))
}

private func makePurchase(
  _ id: String = "product",
  source: PurchaseSource? = nil
) -> InFlightPurchase {
  let product = makeProduct(id)
  return InFlightPurchase(
    product: product,
    source: source ?? .purchaseFunc(product),
    purchaseDate: Date(),
    isFreeTrialAvailable: false,
    isCustomStoreCheckout: false
  )
}

private func makeTransaction(
  _ id: String = "product",
  state: SKPaymentTransactionState = .purchased,
  date: Date? = Date()
) -> StoreTransaction {
  return FakeStoreTransactionFactory.make(FakeSK1Transaction(productId: id, state: state, date: date))
}

@Suite("PurchaseUpdate reducers")
struct PurchaseUpdateTests {
  @Test("begin starts a purchase and finish ends it with its completion")
  func beginAndFinish() {
    var state = PurchaseUpdate.begin(makePurchase()).reduce(PurchaseState())
    state = PurchaseUpdate.completion({ _ in }).reduce(state)
    #expect(state.purchase?.product.productIdentifier == "product")
    #expect(state.completion != nil)

    state = PurchaseUpdate.finish.reduce(state)
    #expect(state.purchase == nil)
    #expect(state.completion == nil)
  }

  @Test("source and free trial change the purchase in progress only")
  func changesWithoutPurchase() {
    let product = makeProduct()
    let empty = PurchaseUpdate.source(.observeFunc(product)).reduce(PurchaseState())
    #expect(empty.purchase == nil)
    #expect(PurchaseUpdate.isFreeTrialAvailable(true).reduce(empty).purchase == nil)

    let started = PurchaseUpdate.begin(makePurchase()).reduce(PurchaseState())
    let observed = PurchaseUpdate.source(.observeFunc(product)).reduce(started)
    guard case .observeFunc = observed.purchase?.source else {
      Issue.record("Expected the source to change")
      return
    }
    #expect(observed.purchase?.purchaseDate == started.purchase?.purchaseDate)
    #expect(PurchaseUpdate.isFreeTrialAvailable(true).reduce(started).purchase?.isFreeTrialAvailable == true)
  }

  @Test("putBack restores a purchase only if none began meanwhile")
  func putBack() {
    let setAside = SetAsidePurchase(purchase: makePurchase("first"), completion: nil)
    let free = PurchaseUpdate.putBack(setAside).reduce(PurchaseState())
    #expect(free.purchase?.product.productIdentifier == "first")

    let busy = PurchaseUpdate.begin(makePurchase("second")).reduce(PurchaseState())
    #expect(PurchaseUpdate.putBack(setAside).reduce(busy).purchase?.product.productIdentifier == "second")
  }

  @Test("a purchased transaction is kept per product unless an older one arrives")
  func keepsLatestTransaction() {
    let now = Date()
    let newer = makeTransaction(date: now)
    let older = makeTransaction(date: now.addingTimeInterval(-60))

    var state = PurchaseUpdate.transaction(newer, result: .purchased).reduce(PurchaseState())
    state = PurchaseUpdate.transaction(older, result: .purchased).reduce(state)
    #expect(state.transactionsByProductId["product"]?.transactionDate == now)
    #expect(state.lastInternalTransaction?.transactionDate == older.transactionDate)
  }

  @Test("a transaction that isn't purchased is only the last internal one")
  func failedTransaction() {
    let failed = makeTransaction(state: .failed)
    let state = PurchaseUpdate.transaction(failed, result: .cancelled).reduce(PurchaseState())
    #expect(state.transactionsByProductId.isEmpty)
    #expect(state.lastInternalTransaction != nil)
  }
}

@Suite("PurchasingCoordinator")
struct PurchasingCoordinatorTests {
  @Test("setting aside takes the purchase and its completion, and putting back restores them")
  func setAside() {
    let coordinator = PurchasingCoordinator(factory: FakeStoreTransactionFactory())
    let product = makeProduct()
    coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: true)
    coordinator.setCompletion { _ in }

    let setAside = coordinator.setAsidePurchase()
    #expect(coordinator.source == nil)
    #expect(coordinator.store.state.completion == nil)
    #expect(setAside.purchase?.isFreeTrialAvailable == true)
    #expect(setAside.completion != nil)

    coordinator.restore(setAside)
    #expect(coordinator.product?.productIdentifier == "product")
    #expect(coordinator.store.state.completion != nil)
  }

  @Test("a completion runs only for a transaction of the product being bought")
  func completionMatchesProduct() async {
    let coordinator = PurchasingCoordinator(factory: FakeStoreTransactionFactory())
    let product = makeProduct()
    coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)
    let calls = Counter()
    coordinator.setCompletion { _ in calls.increment() }

    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "other"), result: .purchased)
    #expect(calls.value == 0)

    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)
    #expect(calls.value == 1)
    #expect(coordinator.transactions["product"] != nil)
  }

  @Test("200 concurrent results call the completion once")
  func concurrentCompletions() async {
    let coordinator = PurchasingCoordinator(factory: FakeStoreTransactionFactory())
    let product = makeProduct()
    coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)
    let calls = Counter()
    coordinator.setCompletion { _ in calls.increment() }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<200 {
        group.addTask {
          await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)
        }
      }
    }
    #expect(calls.value == 1)
  }

  @Test("200 concurrent purchases leave the last one begun, whole")
  func concurrentBegins() async {
    let coordinator = PurchasingCoordinator(factory: FakeStoreTransactionFactory())
    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 {
        group.addTask {
          let product = makeProduct("product-\(index)")
          coordinator.beginPurchase(
            of: product,
            source: .purchaseFunc(product),
            isFreeTrialAvailable: index.isMultiple(of: 2)
          )
          coordinator.setIsFreeTrialAvailable(to: index.isMultiple(of: 2))
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

  @Test("the completion runs with the store unlocked")
  func completionRunsUnlocked() async {
    let coordinator = PurchasingCoordinator(factory: FakeStoreTransactionFactory())
    let product = makeProduct()
    coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)
    let readOnOtherThread = Counter()
    coordinator.setCompletion { _ in
      // Another thread reads the store while the completion is running. If
      // the store were locked, the read would wait until the timeout.
      let done = DispatchSemaphore(value: 0)
      Thread {
        _ = coordinator.source
        done.signal()
      }.start()
      if done.wait(timeout: .now() + 2) == .success {
        readOnOtherThread.increment()
      }
    }

    await coordinator.completePurchase(of: FakeSK1Transaction(productId: "product"), result: .purchased)
    #expect(readOnOtherThread.value == 1)
  }

  @Test("the last internal transaction is taken once")
  func takesLastInternalTransaction() async {
    let coordinator = PurchasingCoordinator(factory: FakeStoreTransactionFactory())
    let product = makeProduct()
    coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)
    await coordinator.completePurchase(
      of: FakeSK1Transaction(productId: "product", state: .failed, date: nil),
      result: .cancelled
    )
    #expect(coordinator.lastInternalTransaction != nil)

    // StoreKit 2 finds nothing for this product in tests, so the lookup falls
    // back to the last internal transaction and takes it.
    let first = await coordinator.getLatestTransaction(
      forProductId: "product",
      factory: FakeStoreTransactionFactory()
    )
    #expect(first != nil)
    #expect(coordinator.lastInternalTransaction == nil)
  }
}

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }

  func increment() {
    lock.lock()
    count += 1
    lock.unlock()
  }
}
