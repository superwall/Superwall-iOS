//
//  TransactionManagerPurchaseTests.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

private final class CancellingPurchaseController: PurchaseController {
  func purchase(product: StoreProduct) async -> PurchaseResult {
    return .cancelled
  }

  func restorePurchases() async -> RestorationResult {
    return .restored
  }
}

private final class NoRedeem: PostPurchaseRedeeming {
  func redeemAfterPurchase() async {}
}

@Suite("TransactionManager purchase handling")
struct TransactionManagerPurchaseTests {
  private func makeTransactionManager(in dependencyContainer: DependencyContainer) -> TransactionManager {
    return TransactionManager(
      storeKitManager: dependencyContainer.storeKitManager,
      receiptManager: dependencyContainer.receiptManager,
      purchaseController: CancellingPurchaseController(),
      placementsQueue: dependencyContainer.placementsQueue,
      purchaseManager: dependencyContainer.purchaseManager,
      productsManager: dependencyContainer.productsManager,
      postPurchaseRedeemer: NoRedeem(),
      factory: dependencyContainer
    )
  }

  @Test("handling a purchase's result doesn't end a purchase that began meanwhile")
  func handlingDoesNotEndNewerPurchase() async {
    let dependencyContainer = DependencyContainer()
    let transactionManager = makeTransactionManager(in: dependencyContainer)
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()

    let first = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "first"))
    let second = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "second"))
    coordinator.beginPurchase(of: first, source: .purchaseFunc(first), isFreeTrialAvailable: false)

    let abandonedProducts = AbandonedProducts()
    transactionManager.trackEvent = { event in
      guard
        let transaction = event as? InternalSuperwallEvent.Transaction,
        case .abandon(let product) = transaction.state
      else {
        return
      }
      abandonedProducts.append(product?.productIdentifier ?? "")
      // Another purchase begins while the first one's abandon is tracked.
      coordinator.beginPurchase(of: second, source: .purchaseFunc(second), isFreeTrialAvailable: false)
    }

    await transactionManager.handle(result: .cancelled, state: .purchasing(.purchaseFunc(first)))

    #expect(abandonedProducts.ids == ["first"])
    #expect(coordinator.purchase?.product.productIdentifier == "second")
    coordinator.reset()
  }

  @Test("observing a second StoreKit 1 purchase abandons the first one, not the second")
  func observingSecondPurchaseAbandonsTheFirst() async throws {
    let dependencyContainer = DependencyContainer()
    let transactionManager = makeTransactionManager(in: dependencyContainer)
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()

    let first = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "first"))
    let second = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "second"))
    let abandonedProducts = AbandonedProducts()
    transactionManager.trackEvent = { event in
      guard
        let transaction = event as? InternalSuperwallEvent.Transaction,
        case .abandon(let product) = transaction.state
      else {
        return
      }
      abandonedProducts.append(product?.productIdentifier ?? "")
    }

    await transactionManager.observeSK1Purchase(of: first)
    await transactionManager.observeSK1Purchase(of: second)

    // The first purchase's completion is dropped, and handled in a task.
    for _ in 0..<200 where abandonedProducts.ids.isEmpty {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(abandonedProducts.ids == ["first"])
    #expect(coordinator.purchase?.product.productIdentifier == "second")
    #expect(coordinator.hasPurchaseInProgress)
    coordinator.reset()
  }
}

private final class AbandonedProducts: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String] = []

  var ids: [String] {
    lock.lock()
    defer { lock.unlock() }
    return values
  }

  func append(_ id: String) {
    lock.lock()
    values.append(id)
    lock.unlock()
  }
}
