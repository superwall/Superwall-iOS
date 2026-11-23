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

/// Records what a purchase causes, in order, and buys with the results it's
/// given.
private final class FakeTransactionContext: TransactionContext, @unchecked Sendable {
  private let lock = NSLock()
  private var _calls: [String] = []
  private var _events: [Trackable] = []
  private var _alertTitles: [String] = []

  var isUsingStoreKit2 = false
  var hasExternalPurchaseController = false
  var isTestMode = false
  var shouldObservePurchases = false
  var paywallOptions = PaywallOptions()
  var triggers: Set<String> = []
  var loadedProducts: [String: StoreProduct] = [:]
  var isAppStoreFreeTrialAvailable = false
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
    return _alertTitles
  }

  private func record(_ call: String) {
    lock.lock()
    _calls.append(call)
    lock.unlock()
  }

  func product(withId id: String) async -> StoreProduct? {
    record("product(withId:)")
    return loadedProducts[id]
  }

  func loadProduct(withId id: String) async -> StoreProduct? {
    record("loadProduct")
    return loadedProducts[id]
  }

  func isAppStoreFreeTrialAvailable(for product: StoreProduct) async -> Bool {
    record("isAppStoreFreeTrialAvailable")
    return isAppStoreFreeTrialAvailable
  }

  func customerInfo(afterLoadAffecting entitlementIds: Set<String>) async -> CustomerInfo {
    record("customerInfo")
    return CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [], isPlaceholder: true)
  }

  func makeStoreTransaction(from transaction: CustomStoreTransaction) async -> StoreTransaction {
    record("makeStoreTransaction")
    return StoreTransaction(
      transaction: transaction,
      configRequestId: "",
      appSessionId: ""
    )
  }

  func track(_ event: Trackable) async {
    lock.lock()
    _events.append(event)
    _calls.append("track:\(type(of: event))")
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
    _alertTitles.append(title)
    _calls.append("presentAlert")
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
    record("sessionDeviceAttributes")
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

private final class CountingRedeemer: PostPurchaseRedeeming, @unchecked Sendable {
  private let lock = NSLock()
  private var _count = 0

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return _count
  }

  func redeemAfterPurchase() async {
    lock.lock()
    _count += 1
    lock.unlock()
  }
}

private final class PendingPurchaseController: PurchaseController {
  func purchase(product: StoreProduct) async -> PurchaseResult {
    return .pending
  }

  func restorePurchases() async -> RestorationResult {
    return .restored
  }
}

@Suite("AppTransactionContext")
struct AppTransactionContextTests {
  private func makeContext(
    in dependencyContainer: DependencyContainer,
    purchaseController: PurchaseController? = nil,
    redeemer: PostPurchaseRedeeming = NoRedeem()
  ) -> AppTransactionContext {
    return AppTransactionContext(
      storeKitManager: dependencyContainer.storeKitManager,
      receiptManager: dependencyContainer.receiptManager,
      purchaseController: purchaseController ?? dependencyContainer.purchaseController,
      placementsQueue: dependencyContainer.placementsQueue,
      purchaseManager: dependencyContainer.purchaseManager,
      productsManager: dependencyContainer.productsManager,
      postPurchaseRedeemer: redeemer,
      factory: dependencyContainer
    )
  }

  @Test("redeeming after a purchase runs the redeemer once")
  func redeemRunsRedeemer() async {
    let redeemer = CountingRedeemer()
    let context = makeContext(in: DependencyContainer(), redeemer: redeemer)

    await context.redeemAfterPurchase().value

    #expect(redeemer.count == 1)
  }

  @Test("buying with the purchase controller returns the controller's result")
  func purchaseControllerResultIsReturned() async {
    let context = makeContext(
      in: DependencyContainer(),
      purchaseController: PendingPurchaseController()
    )
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "product"))

    let result = await context.purchaseWithPurchaseController(product)

    #expect(result == .pending)
  }

  @Test("tracking goes to trackEvent")
  func trackGoesToTrackEvent() async {
    let context = makeContext(in: DependencyContainer())
    let redeemer = CountingRedeemer()
    context.trackEvent = { _ in
      await redeemer.redeemAfterPurchase()
    }

    await context.track(InternalSuperwallEvent.IdentityAlias())

    #expect(redeemer.count == 1)
  }

  @Test("the options and purchase controller it reports are the SDK's")
  func reportsTheSdksSettings() {
    let options = SuperwallOptions()
    options.shouldObservePurchases = true
    options.paywalls.automaticallyDismiss = false
    let dependencyContainer = DependencyContainer(options: options)
    let context = makeContext(in: dependencyContainer)

    #expect(context.shouldObservePurchases)
    #expect(!context.paywallOptions.automaticallyDismiss)
    #expect(context.hasExternalPurchaseController == dependencyContainer.makeHasExternalPurchaseController())
    #expect(!context.isTestMode)
  }

  @Test("a product that isn't loaded isn't found")
  func unknownProductIsNotFound() async {
    let context = makeContext(in: DependencyContainer())

    #expect(await context.product(withId: "unknown") == nil)
  }

  @Test("the manager built from the SDK's managers tracks purchases through its real context")
  func realManagerTracksThroughItsContext() async {
    let dependencyContainer = DependencyContainer()
    let transactionManager = TransactionManager(
      storeKitManager: dependencyContainer.storeKitManager,
      receiptManager: dependencyContainer.receiptManager,
      purchaseController: PendingPurchaseController(),
      placementsQueue: dependencyContainer.placementsQueue,
      purchaseManager: dependencyContainer.purchaseManager,
      productsManager: dependencyContainer.productsManager,
      postPurchaseRedeemer: NoRedeem(),
      factory: dependencyContainer
    )
    let tracked = CountingRedeemer()
    transactionManager.trackEvents { _ in
      await tracked.redeemAfterPurchase()
    }
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "product"))
    let purchase = coordinator.beginPurchase(
      of: product,
      source: .purchaseFunc(product),
      isFreeTrialAvailable: false
    )

    await transactionManager.trackCancelled(purchase: purchase)

    #expect(transactionManager.context is AppTransactionContext)
    #expect(tracked.count == 1)
    coordinator.reset()
  }
}

@Suite("TransactionManager side effects")
struct TransactionContextTests {
  private func makeTransactionManager(
    in dependencyContainer: DependencyContainer,
    context: FakeTransactionContext
  ) -> TransactionManager {
    return TransactionManager(
      context: context,
      restoreContext: AppRestoreContext(
        purchaseController: dependencyContainer.purchaseController,
        purchaseManager: dependencyContainer.purchaseManager,
        factory: dependencyContainer
      ),
      factory: dependencyContainer
    )
  }

  private func makeCustomProduct(
    subscription: SuperwallProductSubscription? = nil
  ) -> StoreProduct {
    return StoreProduct(
      customProduct: APIStoreProduct(
        superwallProduct: SuperwallProduct(
          object: "product",
          identifier: "custom",
          platform: .custom,
          price: SuperwallProductPrice(amount: 999, currency: "USD"),
          subscription: subscription,
          entitlements: [],
          storefront: "USA"
        ),
        entitlements: []
      )
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
    #expect(context.calls.contains("purchaseInTestMode"))
    #expect(!context.calls.contains("purchaseWithStoreKit"))
    #expect(!context.calls.contains("purchaseWithPurchaseController"))
  }

  @Test("an observed purchase begins with the product and trial check the context gives")
  func observedPurchaseUsesContextLookups() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "observed"))
    context.loadedProducts = ["observed": product]
    context.isAppStoreFreeTrialAvailable = true
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()

    await transactionManager.observeSK1Transaction(for: "observed")

    #expect(context.calls.contains("loadProduct"))
    #expect(context.calls.contains("isAppStoreFreeTrialAvailable"))
    #expect(coordinator.purchase?.product.productIdentifier == "observed")
    #expect(coordinator.purchase?.isFreeTrialAvailable == true)
    coordinator.reset()
  }

  @Test("a purchase isn't observed when its product can't be loaded")
  func observedPurchaseWithoutProductBeginsNothing() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()

    await transactionManager.observeSK1Transaction(for: "missing")

    #expect(context.calls == ["loadProduct"])
    #expect(!coordinator.hasPurchaseInProgress)
  }

  @Test("a purchase that succeeds is redeemed, remembered, tracked and sent, in that order")
  func successfulPurchaseRunsItsEffectsInOrder() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()
    let product = makeCustomProduct()
    product.customTransactionId = "transaction"
    let purchase = coordinator.beginPurchase(
      of: product,
      source: .purchaseFunc(product),
      isFreeTrialAvailable: false
    )

    await transactionManager.handle(
      result: .purchased,
      state: .purchasing(.purchaseFunc(product)),
      purchase: purchase
    )

    #expect(context.calls == [
      "makeStoreTransaction",
      "redeemAfterPurchase",
      "rememberHandledTransaction",
      "sessionDeviceAttributes",
      "track:Transaction",
      "flushPlacements",
      "track:NonRecurringProductPurchase"
    ])
    let completed = context.events.compactMap { $0 as? InternalSuperwallEvent.Transaction }
    if case .complete(let completedProduct, let transaction, _) = completed.first?.state {
      #expect(completedProduct.productIdentifier == "custom")
      #expect(transaction != nil)
    } else {
      Issue.record("Expected a completed transaction to be tracked")
    }
    #expect(!coordinator.hasPurchaseInProgress)
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
    #expect(pendingEvents.first?.product?.productIdentifier == "product")
    #expect(!coordinator.hasPurchaseInProgress)
  }

  @Test("a failed purchase is tracked before its alert shows")
  func failedPurchaseIsTrackedBeforeItsAlert() async {
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
      result: .failed(PurchaseError.productUnavailable),
      state: .purchasing(.purchaseFunc(product)),
      purchase: purchase
    )

    #expect(context.calls == ["track:Transaction", "presentAlert"])
    let failEvents = context.events.compactMap { $0 as? InternalSuperwallEvent.Transaction }
    if case .fail = failEvents.first?.state {
      #expect(failEvents.first?.product?.productIdentifier == "product")
    } else {
      Issue.record("Expected a failed transaction to be tracked")
    }
    #expect(!coordinator.hasPurchaseInProgress)
  }

  @Test("a purchase the app made itself is tracked as complete, then ended")
  func observedPurchaseIsTrackedThenEnded() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    context.shouldObservePurchases = true
    // No trial is on offer, so only the observed transaction says one started.
    let product = makeCustomProduct(
      subscription: SuperwallProductSubscription(
        period: .month,
        periodCount: 1,
        trialPeriodDays: nil,
        trialPeriodPrice: nil
      )
    )
    context.loadedProducts = ["custom": product]
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()

    await transactionManager.logObservedPurchase(ofProductId: "custom", startedOffer: true)

    let completed = context.events
      .compactMap { $0 as? InternalSuperwallEvent.Transaction }
      .filter {
        if case .complete = $0.state {
          return true
        }
        return false
      }
    #expect(completed.count == 1)
    if case .complete(let completedProduct, _, let type) = completed.first?.state {
      #expect(completedProduct.productIdentifier == "custom")
      #expect(type == .freeTrialStart)
    }
    #expect(completed.first?.isObserved == true)
    #expect(!coordinator.hasPurchaseInProgress)
  }

  @Test("a purchase the app made itself isn't logged when its product can't be loaded")
  func observedPurchaseWithoutProductLogsNothing() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    context.shouldObservePurchases = true
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    coordinator.reset()

    await transactionManager.logObservedPurchase(ofProductId: "missing", startedOffer: false)

    #expect(context.calls == ["loadProduct"])
    #expect(!coordinator.hasPurchaseInProgress)
  }

  @Test("a custom product without a purchase controller fails without buying")
  func customProductWithoutControllerFails() async {
    let dependencyContainer = DependencyContainer()
    let context = FakeTransactionContext()
    let transactionManager = makeTransactionManager(in: dependencyContainer, context: context)
    dependencyContainer.makePurchasingCoordinator().reset()
    let product = makeCustomProduct()

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
