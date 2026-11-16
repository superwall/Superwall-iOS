//
//  TransactionContextTests.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Records what a purchase causes, and buys with the results it's given.
private final class FakeTransactionContext: TransactionContext, @unchecked Sendable {
  private let lock = NSLock()
  private var _calls: [String] = []
  private var _events: [Trackable] = []
  private var _alerts: [(title: String, source: GenericSource)] = []

  var isUsingStoreKit2 = false
  var hasExternalPurchaseController = false
  var isTestMode = false
  var superwallOptions = SuperwallOptions()
  var storeKitResult: PurchaseResult = .cancelled
  var purchaseControllerResult: PurchaseResult = .cancelled
  var testModeResult: PurchaseResult?

  var calls: [String] {
    lock.lock()
    defer { lock.unlock() }
    return _calls
  }

  var events: [Trackable] {
    lock.lock()
    defer { lock.unlock() }
    return _events
  }

  var alertTitles: [String] {
    lock.lock()
    defer { lock.unlock() }
    return _alerts.map(\.title)
  }

  private func record(_ call: String) {
    lock.lock()
    _calls.append(call)
    lock.unlock()
  }

  func track(_ event: Trackable) async {
    lock.lock()
    _events.append(event)
    lock.unlock()
  }

  func purchaseWithPurchaseController(_ product: StoreProduct) async -> PurchaseResult {
    record("purchaseWithPurchaseController")
    return purchaseControllerResult
  }

  func purchaseWithStoreKit(_ product: StoreProduct) async -> PurchaseResult {
    record("purchaseWithStoreKit")
    return storeKitResult
  }

  func purchaseInTestMode(_ product: StoreProduct, source: PurchaseSource) async -> PurchaseResult? {
    record("purchaseInTestMode")
    return testModeResult
  }

  func presentAlert(title: String, message: String, source: GenericSource) async {
    lock.lock()
    _alerts.append((title, source))
    lock.unlock()
  }

  func reloadPurchasedProducts() async {
    record("reloadPurchasedProducts")
  }

  func redeemAfterPurchase() -> Task<Void, Never> {
    record("redeemAfterPurchase")
    return Task {}
  }

  func rememberHandledTransaction(_ transaction: StoreTransaction?) async {
    record("rememberHandledTransaction")
  }

  func sessionDeviceAttributes() async -> [String: Any] {
    return [:]
  }

  func flushPlacements() async {
    record("flushPlacements")
  }

  func scheduleNotifications(_ notifications: [LocalNotification], fromPaywallId paywallId: String) async {
    record("scheduleNotifications")
  }

  #if canImport(WebKit)
  @MainActor
  func info(of paywall: PaywallViewController) -> PaywallInfo {
    return .empty()
  }

  @MainActor
  func introOfferToken(forProductId productId: String, on paywall: PaywallViewController) -> IntroOfferToken? {
    return nil
  }

  @MainActor
  func referenceName(forCacheKey cacheKey: String, on paywall: PaywallViewController) -> String? {
    return nil
  }

  @MainActor
  func notify(_ paywall: PaywallViewController, of message: PaywallMessage) {
    record("notify")
  }

  @MainActor
  func updateLoading(_ change: PaywallLoadingChange, on paywall: PaywallViewController) {
    record("updateLoading")
  }

  @MainActor
  func markPurchaseCompleted(_ product: StoreProduct, on paywall: PaywallViewController) {
    record("markPurchaseCompleted")
  }

  func dismiss(_ paywall: PaywallViewController, result: PaywallResult) async {
    record("dismiss")
  }
  #endif
}

private final class NoRedeem: PostPurchaseRedeeming {
  func redeemAfterPurchase() async {}
}

@Suite("TransactionManager side effects")
struct TransactionContextTests {
  private func makeTransactionManager(
    in dependencyContainer: DependencyContainer,
    context: FakeTransactionContext
  ) -> TransactionManager {
    return TransactionManager(
      storeKitManager: dependencyContainer.storeKitManager,
      receiptManager: dependencyContainer.receiptManager,
      purchaseController: dependencyContainer.purchaseController,
      placementsQueue: dependencyContainer.placementsQueue,
      purchaseManager: dependencyContainer.purchaseManager,
      productsManager: dependencyContainer.productsManager,
      postPurchaseRedeemer: NoRedeem(),
      factory: dependencyContainer,
      context: context
    )
  }

  private func abandonedProductIds(in events: [Trackable]) -> [String] {
    return events.compactMap { event in
      guard
        let transaction = event as? InternalSuperwallEvent.Transaction,
        case .abandon(let product) = transaction.state
      else {
        return nil
      }
      return product?.productIdentifier
    }
  }

  @Test("the purchase function buys through StoreKit and tracks the abandon through the context")
  func purchaseFunctionGoesThroughContext() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    dependencyContainer.makePurchasingCoordinator().reset()
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "product"))

    let result = await transactionManager.purchase(.purchaseFunc(product))

    #expect(result == .cancelled)
    #expect(context.calls.contains("purchaseInTestMode"))
    #expect(context.calls.contains("purchaseWithStoreKit"))
    #expect(!context.calls.contains("purchaseWithPurchaseController"))
    #expect(abandonedProductIds(in: context.events) == ["product"])
    #expect(!dependencyContainer.makePurchasingCoordinator().hasPurchaseInProgress)
  }

  @Test("a test mode result is used instead of buying")
  func testModeResultSkipsBuying() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    context.testModeResult = .cancelled
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    dependencyContainer.makePurchasingCoordinator().reset()
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "product"))

    let result = await transactionManager.purchase(.purchaseFunc(product))

    #expect(result == .cancelled)
    #expect(!context.calls.contains("purchaseWithStoreKit"))
    #expect(!context.calls.contains("purchaseWithPurchaseController"))
  }

  @Test("a pending purchase shows its alert through the context")
  func pendingPurchaseShowsAlert() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "product"))
    let purchase = coordinator.beginPurchase(
      of: product,
      source: .purchaseFunc(product),
      isFreeTrialAvailable: false
    )

    await transactionManager.handle(
      result: .pending,
      state: .purchasing(.purchaseFunc(product)),
      purchase: purchase
    )

    #expect(context.alertTitles.count == 1)
    let pendingEvents = context.events.compactMap { $0 as? InternalSuperwallEvent.Transaction }
    #expect(pendingEvents.count == 1)
    #expect(!coordinator.hasPurchaseInProgress)
  }

  @Test("a custom product without a purchase controller fails without buying")
  func customProductWithoutControllerFails() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    dependencyContainer.makePurchasingCoordinator().reset()
    let product = StoreProduct(
      customProduct: APIStoreProduct(
        superwallProduct: SuperwallProduct(
          object: "product",
          identifier: "custom",
          platform: .custom,
          price: SuperwallProductPrice(amount: 999, currency: "USD"),
          subscription: nil,
          entitlements: [],
          storefront: "USA"
        ),
        entitlements: []
      )
    )

    let result = await transactionManager.purchase(.purchaseFunc(product))

    if case .failed = result {} else {
      Issue.record("Expected a failure, got \(result)")
    }
    #expect(!context.calls.contains("purchaseWithStoreKit"))
    #expect(!context.calls.contains("purchaseWithPurchaseController"))
  }

  @Test("a test mode purchase isn't redeemed")
  func testModeSkipsRedeem() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    context.isTestMode = true
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "product"))

    let redeem = await transactionManager.redeemAfterPurchase(for: product)

    #expect(redeem == nil)
    #expect(!context.calls.contains("reloadPurchasedProducts"))
    #expect(!context.calls.contains("redeemAfterPurchase"))
  }

  @Test("an App Store purchase reloads its receipt before it's redeemed")
  func appStorePurchaseReloadsThenRedeems() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "product"))

    let redeem = await transactionManager.redeemAfterPurchase(for: product)

    #expect(redeem != nil)
    #expect(context.calls == ["reloadPurchasedProducts", "redeemAfterPurchase"])
  }
}
