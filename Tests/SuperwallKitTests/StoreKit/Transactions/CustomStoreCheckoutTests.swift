//
//  CustomStoreCheckoutTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 2026-10-21.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Records the purchases and restores it's asked for.
private final class RecordingPurchaseController: PurchaseController {
  private(set) var purchaseCount = 0
  private(set) var restoreCount = 0
  /// How long each purchase takes.
  var purchaseDurationNs: UInt64 = 0

  func purchase(product: StoreProduct) async -> PurchaseResult {
    purchaseCount += 1
    try? await Task.sleep(nanoseconds: purchaseDurationNs)
    return .purchased
  }

  func restorePurchases() async -> RestorationResult {
    restoreCount += 1
    return .restored
  }
}

/// Records the custom purchase refreshes `TransactionManager` starts.
private actor RecordingEntitlementsRefresher: CustomPurchaseEntitlementsRefreshing {
  private(set) var refreshedEntitlementIds: [Set<String>] = []

  func refreshEntitlementsAfterCustomPurchase(expecting entitlementIds: Set<String>) async {
    refreshedEntitlementIds.append(entitlementIds)
  }
}

/// Records the transaction events `TransactionManager` tracks.
private actor TrackedTransactions {
  private(set) var events: [InternalSuperwallEvent.Transaction] = []

  func record(_ event: Trackable) {
    if let transaction = event as? InternalSuperwallEvent.Transaction {
      events.append(transaction)
    }
  }

  /// Gives events tracked from a detached task time to land.
  func waitForEvents(count: Int) async -> [InternalSuperwallEvent.Transaction] {
    for _ in 0..<40 where events.count < count {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    return events
  }
}

/// Decodes the `event_name`s of the messages passed to a paywall's page.
@MainActor
private func pageEvents(in webView: FakeWebView) -> [String] {
  return webView.evaluatedScripts.flatMap { script -> [String] in
    guard
      let start = script.range(of: "accept64('"),
      let end = script.range(of: "')", range: start.upperBound..<script.endIndex),
      let data = Data(base64Encoded: String(script[start.upperBound..<end.lowerBound])),
      let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return []
    }
    return events.compactMap { $0["event_name"] as? String }
  }
}

/// Records the checkout steps a paywall hands over, taking a while over each start.
@MainActor
private final class SlowStartEventDelegate: PaywallViewControllerEventDelegate {
  private(set) var log: [String] = []

  func eventDidOccur(_ paywallEvent: PaywallWebEvent, on paywallViewController: PaywallViewController) async {
    guard case .customStoreCheckout(let checkout) = paywallEvent else {
      return
    }
    switch checkout {
    case .start:
      log.append("start began")
      try? await Task.sleep(nanoseconds: 200_000_000)
      log.append("start ended")
    default:
      log.append("\(checkout)")
    }
  }

  func waitForLog(count: Int) async -> [String] {
    for _ in 0..<40 where log.count < count {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    return log
  }
}

/// Records the alerts a paywall presents.
@MainActor
private final class AlertRecordingPaywallViewController: PaywallViewController {
  private(set) var alertMessages: [String?] = []

  override func presentAlert(
    title: String? = nil,
    message: String? = nil,
    actionTitle: String? = nil,
    closeActionTitle: String = "Done",
    action: (() -> Void)? = nil,
    onClose: (() -> Void)? = nil
  ) {
    alertMessages.append(message)
  }
}

/// Tests for finishing the custom store checkouts a paywall runs itself.
@Suite(.serialized)
@MainActor
struct CustomStoreCheckoutTests {
  let dependencyContainer: DependencyContainer
  private let purchaseController: RecordingPurchaseController
  private let refresher = RecordingEntitlementsRefresher()
  private let tracked = TrackedTransactions()

  private let productId = "pro_monthly"
  private let serverTransactionId = "9b2f6a8e-6a2c-4d4b-9f5e-2f2b7c1d0e11"

  init() {
    purchaseController = RecordingPurchaseController()
    dependencyContainer = DependencyContainer()
    dependencyContainer.storage.delete(LatestRedeemResponse.self)
    dependencyContainer.storage.delete(LastWebEntitlementsFetchDate.self)
  }

  // MARK: - Helpers

  private func makeCustomStoreProduct() -> StoreProduct {
    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: productId,
      platform: .custom,
      price: SuperwallProductPrice(amount: 999, currency: "USD"),
      subscription: SuperwallProductSubscription(
        period: .month,
        periodCount: 1,
        trialPeriodDays: nil,
        trialPeriodPrice: nil
      ),
      entitlements: [],
      storefront: "USA"
    )
    let apiProduct = APIStoreProduct(
      superwallProduct: superwallProduct,
      entitlements: [Entitlement(id: "pro", type: .serviceLevel, isActive: false)]
    )
    return StoreProduct(customProduct: apiProduct)
  }

  /// A transaction manager selling `productId` as a custom product.
  private func makeTransactionManager(
    in dependencyContainer: DependencyContainer? = nil,
    entitlementsRefresher: CustomPurchaseEntitlementsRefreshing? = nil
  ) async -> (TransactionManager, StoreProduct) {
    let dependencyContainer = dependencyContainer ?? self.dependencyContainer
    let product = makeCustomStoreProduct()
    await dependencyContainer.storeKitManager.setProduct(product, forIdentifier: productId)
    let transactionManager = TransactionManager(
      storeKitManager: dependencyContainer.storeKitManager,
      receiptManager: dependencyContainer.receiptManager,
      purchaseController: purchaseController,
      placementsQueue: dependencyContainer.placementsQueue,
      purchaseManager: dependencyContainer.purchaseManager,
      productsManager: dependencyContainer.productsManager,
      entitlementsRefresher: entitlementsRefresher ?? refresher,
      factory: dependencyContainer
    )
    let tracked = tracked
    transactionManager.trackEvent = { event in
      await tracked.record(event)
    }
    return (transactionManager, product)
  }

  private func makePaywall(
    in dependencyContainer: DependencyContainer? = nil,
    eventDelegate: PaywallViewControllerEventDelegate? = nil
  ) -> (AlertRecordingPaywallViewController, PaywallFinishRecorder) {
    let dependencyContainer = dependencyContainer ?? self.dependencyContainer
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = AlertRecordingPaywallViewController(
      paywall: .stub(),
      eventDelegate: eventDelegate,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: dependencyContainer.paywallManager.cache,
      paywallArchiveManager: nil,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    messageHandler.delegate = paywallVc
    let finishes = PaywallFinishRecorder()
    paywallVc.delegate = PaywallViewControllerDelegateAdapter(
      swiftDelegate: finishes,
      objcDelegate: nil
    )
    return (paywallVc, finishes)
  }

  private func webView(of paywallVc: PaywallViewController) -> FakeWebView {
    return paywallVc.webView as! FakeWebView
  }

  /// Gives a message sent to the page from a task time to land.
  private func waitForPageEvent(_ name: String, in paywallVc: PaywallViewController) async -> [String] {
    for _ in 0..<40 where !pageEvents(in: webView(of: paywallVc)).contains(name) {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    return pageEvents(in: webView(of: paywallVc))
  }

  private func store(of event: InternalSuperwallEvent.Transaction) async -> String? {
    return await event.getSuperwallParameters()["store"] as? String
  }

  private func isInternal(_ event: InternalSuperwallEvent.Transaction) -> Bool {
    if case .internal = event.source {
      return true
    }
    return false
  }

  // MARK: - Start

  @Test("Start tracks transaction_start for the product with the server's transaction id")
  func start_tracksTransactionStart() async throws {
    let (transactionManager, product) = await makeTransactionManager()
    let (paywallVc, _) = makePaywall()
    paywallVc.loadingState = .ready

    await transactionManager.handleCustomStoreCheckout(
      .start(productId: productId, customTransactionId: serverTransactionId),
      paywallViewController: paywallVc
    )

    let events = await tracked.events
    let event = try #require(events.first)
    #expect(events.count == 1)
    guard case .start(let startedProduct) = event.state else {
      Issue.record("Expected transaction_start, got \(event.state)")
      return
    }
    #expect(startedProduct.productIdentifier == productId)
    #expect(isInternal(event))
    #expect(await store(of: event) == "CUSTOM")
    #expect(product.customTransactionId == serverTransactionId)
    // The checkout's browser owns the loading state, not the purchase spinner.
    #expect(paywallVc.loadingState == .ready)
    #expect(paywallVc.customStoreCheckoutProductId == productId)
    #expect(await waitForPageEvent("transaction_start", in: paywallVc).contains("transaction_start"))
    #expect(purchaseController.purchaseCount == 0)
    await dependencyContainer.makePurchasingCoordinator().reset()
  }

  // MARK: - Complete

  @Test("Complete finishes the purchase like a purchase controller's, with the server's transaction id")
  func complete_finishesPurchase() async throws {
    let (transactionManager, product) = await makeTransactionManager()
    let (paywallVc, finishes) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(
      .start(productId: productId, customTransactionId: serverTransactionId),
      paywallViewController: paywallVc
    )
    await transactionManager.handleCustomStoreCheckout(
      .complete(productId: productId, customTransactionId: serverTransactionId, shouldDismiss: true),
      paywallViewController: paywallVc
    )

    let events = await tracked.events
    let completes = events.filter {
      if case .complete = $0.state { return true }
      return false
    }
    let complete = try #require(completes.first)
    #expect(completes.count == 1)
    guard case let .complete(completedProduct, transaction, _) = complete.state else {
      return
    }
    #expect(completedProduct.productIdentifier == productId)
    #expect(transaction?.originalTransactionIdentifier == serverTransactionId)
    #expect(isInternal(complete))
    #expect(await store(of: complete) == "CUSTOM")

    #expect(await refresher.refreshedEntitlementIdsEventually() == [["pro"]])
    #expect(await finishes.waitForResults() == [.purchased(product)])
    #expect(await waitForPageEvent("transaction_complete", in: paywallVc).contains("transaction_complete"))
    #expect(paywallVc.customStoreCheckoutProductId == nil)
    #expect(purchaseController.purchaseCount == 0)
    #expect(await dependencyContainer.makePurchasingCoordinator().source == nil)
  }

  @Test("Complete keeps the paywall open when the purchase action doesn't close it")
  func complete_withoutShouldDismiss_keepsPaywallOpen() async {
    let (transactionManager, _) = await makeTransactionManager()
    let (paywallVc, finishes) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(
      .complete(productId: productId, customTransactionId: serverTransactionId, shouldDismiss: false),
      paywallViewController: paywallVc
    )

    let events = await tracked.events
    #expect(events.contains {
      if case .complete = $0.state { return true }
      return false
    })
    #expect(await finishes.waitForResults().isEmpty)
    #expect(purchaseController.purchaseCount == 0)
  }

  @Test("Complete without a start, e.g. after another purchase replaced it, still finishes the purchase")
  func complete_withoutStart_finishesPurchase() async throws {
    let (transactionManager, product) = await makeTransactionManager()
    let (paywallVc, finishes) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(
      .complete(productId: productId, customTransactionId: serverTransactionId, shouldDismiss: true),
      paywallViewController: paywallVc
    )

    let events = await tracked.events
    // No transaction_start: the paywall reported it, or didn't, when it opened the checkout.
    #expect(events.count == 1)
    guard case let .complete(_, transaction, _) = try #require(events.first).state else {
      Issue.record("Expected transaction_complete")
      return
    }
    #expect(transaction?.originalTransactionIdentifier == serverTransactionId)
    #expect(product.customTransactionId == serverTransactionId)
    #expect(await finishes.waitForResults() == [.purchased(product)])
  }

  // MARK: - Abandon

  @Test("Abandon tracks transaction_abandon for the custom product")
  func abandon_tracksTransactionAbandon() async throws {
    let (transactionManager, _) = await makeTransactionManager()
    let (paywallVc, finishes) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(
      .start(productId: productId, customTransactionId: serverTransactionId),
      paywallViewController: paywallVc
    )
    await transactionManager.handleCustomStoreCheckout(
      .abandon(productId: productId),
      paywallViewController: paywallVc
    )

    let events = await tracked.events
    #expect(events.count == 2)
    let abandon = try #require(events.last)
    guard case .abandon(let abandonedProduct) = abandon.state else {
      Issue.record("Expected transaction_abandon, got \(abandon.state)")
      return
    }
    #expect(abandonedProduct?.productIdentifier == productId)
    #expect(isInternal(abandon))
    #expect(await store(of: abandon) == "CUSTOM")
    #expect(paywallVc.loadingState == .ready)
    #expect(await waitForPageEvent("transaction_abandon", in: paywallVc).contains("transaction_abandon"))
    #expect(paywallVc.customStoreCheckoutProductId == nil)
    #expect(await finishes.waitForResults().isEmpty)
    #expect(purchaseController.purchaseCount == 0)
    #expect(await dependencyContainer.makePurchasingCoordinator().source == nil)
  }

  // MARK: - Fail

  @Test("Fail tracks transaction_fail and shows the purchase failure alert")
  func fail_tracksTransactionFailAndAlerts() async throws {
    let (transactionManager, _) = await makeTransactionManager()
    let (paywallVc, _) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(
      .fail(productId: productId, message: "Checkout is unavailable"),
      paywallViewController: paywallVc
    )

    let events = await tracked.waitForEvents(count: 1)
    let fail = try #require(events.first)
    guard case .fail(.failure(let message, let failedProduct)) = fail.state else {
      Issue.record("Expected transaction_fail, got \(fail.state)")
      return
    }
    #expect(message == "Checkout is unavailable")
    #expect(failedProduct.productIdentifier == productId)
    #expect(isInternal(fail))
    #expect(await store(of: fail) == "CUSTOM")
    #expect(paywallVc.alertMessages == ["Checkout is unavailable"])
    #expect(purchaseController.purchaseCount == 0)
  }

  // MARK: - Start time

  @Test("Complete reports the checkout's start as its purchase date")
  func complete_keepsStartAsPurchaseDate() async throws {
    let (transactionManager, _) = await makeTransactionManager()
    let (paywallVc, _) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(
      .start(productId: productId, customTransactionId: serverTransactionId),
      paywallViewController: paywallVc
    )
    let startedAt = try #require(await dependencyContainer.makePurchasingCoordinator().purchaseDate)
    try? await Task.sleep(nanoseconds: 100_000_000)
    await transactionManager.handleCustomStoreCheckout(
      .complete(productId: productId, customTransactionId: serverTransactionId, shouldDismiss: false),
      paywallViewController: paywallVc
    )

    let complete = try #require(await tracked.events.last)
    guard case let .complete(_, transaction, _) = complete.state else {
      Issue.record("Expected transaction_complete, got \(complete.state)")
      return
    }
    #expect(transaction?.transactionDate == startedAt)
  }

  // MARK: - Another purchase in progress

  @Test("A step doesn't take over another purchase in progress", arguments: [
    CustomStoreCheckout.start(productId: "pro_monthly", customTransactionId: "txn"),
    .complete(productId: "pro_monthly", customTransactionId: "txn", shouldDismiss: true),
    .abandon(productId: "pro_monthly"),
    .fail(productId: "pro_monthly", message: "Unavailable")
  ])
  func otherPurchaseInProgress_isLeftAlone(checkout: CustomStoreCheckout) async {
    let (transactionManager, _) = await makeTransactionManager()
    let (paywallVc, finishes) = makePaywall()
    let appStoreProduct = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: "app_store_product"),
      entitlements: [.stub()]
    )
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    // An App Store purchase from the same paywall, waiting on the App Store.
    await coordinator.beginPurchase(
      of: appStoreProduct,
      source: .internal("app_store_product", paywallVc, true),
      isFreeTrialAvailable: false
    )

    await transactionManager.handleCustomStoreCheckout(checkout, paywallViewController: paywallVc)

    #expect(await tracked.waitForEvents(count: 1).isEmpty)
    #expect(await coordinator.product?.productIdentifier == "app_store_product")
    #expect(await coordinator.isCustomStoreCheckout == false)
    #expect(await finishes.waitForResults().isEmpty)
    #expect(paywallVc.alertMessages.isEmpty)
    #expect(paywallVc.customStoreCheckoutProductId == nil)
    await coordinator.reset()
  }

  @Test("A step waits for a purchase started from the paywall, then finishes the checkout")
  func step_waitsForPaywallPurchase() async throws {
    let purchaseController = RecordingPurchaseController()
    purchaseController.purchaseDurationNs = 300_000_000
    let dependencyContainer = DependencyContainer(purchaseController: purchaseController)
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let product = makeCustomStoreProduct()
    await dependencyContainer.storeKitManager.setProduct(product, forIdentifier: productId)
    let tracked = TrackedTransactions()
    dependencyContainer.transactionManager.trackEvent = { event in
      await tracked.record(event)
    }
    let (paywallVc, _) = makePaywall(in: dependencyContainer)

    // A purchase through the purchase controller, then the checkout completes while it's in flight.
    let purchase = Task { @MainActor in
      await superwall.eventDidOccur(
        .initiatePurchase(productId: productId, shouldDismiss: false),
        on: paywallVc
      )
    }
    try? await Task.sleep(nanoseconds: 50_000_000)
    await superwall.eventDidOccur(
      .customStoreCheckout(
        .complete(productId: productId, customTransactionId: serverTransactionId, shouldDismiss: false)
      ),
      on: paywallVc
    )
    await purchase.value

    let completedIds = await tracked.events.compactMap { event -> String? in
      guard case let .complete(_, transaction, _) = event.state else {
        return nil
      }
      return transaction?.originalTransactionIdentifier
    }
    // The purchase finished with its own transaction, then the checkout with the server's.
    #expect(completedIds.count == 2)
    #expect(completedIds.first != serverTransactionId)
    #expect(completedIds.last == serverTransactionId)
    #expect(purchaseController.purchaseCount == 1)
  }

  // MARK: - Ordering

  @Test("The paywall hands over checkout steps one at a time, in order")
  func steps_areHandedOverInOrder() async {
    let eventDelegate = SlowStartEventDelegate()
    let (paywallVc, _) = makePaywall(eventDelegate: eventDelegate)

    paywallVc.handleCustomStoreCheckout(.start(productId: productId, customTransactionId: serverTransactionId))
    paywallVc.handleCustomStoreCheckout(.abandon(productId: productId))

    let log = await eventDelegate.waitForLog(count: 3)
    #expect(log == ["start began", "start ended", "\(CustomStoreCheckout.abandon(productId: productId))"])
  }

  // MARK: - Subscription status

  private func makeRedeemer(
    in dependencyContainer: DependencyContainer,
    superwall: Superwall
  ) -> (WebEntitlementRedeemer, NetworkMock) {
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = EntitlementsResponse(
      customerInfo: CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: [Entitlement(id: "pro", isActive: true, store: .custom)]
      )
    )
    let redeemer = WebEntitlementRedeemer(
      network: network,
      storage: dependencyContainer.storage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: dependencyContainer.purchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      customPurchaseRefreshDelaysNs: [0, 0, 0],
      superwall: superwall
    )
    return (redeemer, network)
  }

  @Test("Without a purchase controller, a completed checkout makes the subscription status active")
  func complete_withoutPurchaseController_activatesSubscription() async {
    defer {
      dependencyContainer.storage.delete(LatestRedeemResponse.self)
      dependencyContainer.storage.delete(LastWebEntitlementsFetchDate.self)
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let (redeemer, _) = makeRedeemer(in: dependencyContainer, superwall: superwall)
    let (transactionManager, _) = await makeTransactionManager(entitlementsRefresher: redeemer)
    let (paywallVc, _) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(
      .complete(productId: productId, customTransactionId: serverTransactionId, shouldDismiss: false),
      paywallViewController: paywallVc
    )

    for _ in 0..<40 where !superwall.subscriptionStatus.isActive {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    #expect(superwall.subscriptionStatus == .active([Entitlement(id: "pro", isActive: true, store: .custom)]))
  }

  @Test("With a purchase controller, a completed checkout leaves the subscription status to the app")
  func complete_withPurchaseController_doesNotSetSubscriptionStatus() async {
    let purchaseController = RecordingPurchaseController()
    let dependencyContainer = DependencyContainer(purchaseController: purchaseController)
    defer {
      dependencyContainer.storage.delete(LatestRedeemResponse.self)
      dependencyContainer.storage.delete(LastWebEntitlementsFetchDate.self)
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let (redeemer, network) = makeRedeemer(in: dependencyContainer, superwall: superwall)
    let (transactionManager, _) = await makeTransactionManager(
      in: dependencyContainer,
      entitlementsRefresher: redeemer
    )
    let (paywallVc, _) = makePaywall(in: dependencyContainer)
    let statusBefore = superwall.subscriptionStatus

    await transactionManager.handleCustomStoreCheckout(
      .complete(productId: productId, customTransactionId: serverTransactionId, shouldDismiss: false),
      paywallViewController: paywallVc
    )

    for _ in 0..<40 where dependencyContainer.entitlementsInfo.web.isEmpty {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    // The web entitlements update as they do for any purchase...
    #expect(network.getEntitlementsCallCount >= 1)
    #expect(dependencyContainer.entitlementsInfo.web.map(\.id) == ["pro"])
    // ...but the status is the app's to set, and its purchase controller isn't asked to buy.
    #expect(superwall.subscriptionStatus == statusBefore)
    #expect(purchaseController.purchaseCount == 0)
    #expect(self.purchaseController.purchaseCount == 0)
  }

  // MARK: - Unknown products

  @Test("A checkout of a product the paywall doesn't sell is ignored", arguments: [
    CustomStoreCheckout.start(productId: "unknown", customTransactionId: "txn"),
    .complete(productId: "unknown", customTransactionId: "txn", shouldDismiss: true),
    .abandon(productId: "unknown"),
    .fail(productId: "unknown", message: "Unavailable")
  ])
  func unknownProduct_isIgnored(checkout: CustomStoreCheckout) async {
    let (transactionManager, _) = await makeTransactionManager()
    let (paywallVc, finishes) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(checkout, paywallViewController: paywallVc)

    #expect(await tracked.waitForEvents(count: 1).isEmpty)
    #expect(await finishes.waitForResults().isEmpty)
    #expect(paywallVc.alertMessages.isEmpty)
    #expect(paywallVc.customStoreCheckoutProductId == nil)
    #expect(purchaseController.purchaseCount == 0)
  }

  @Test("A checkout of an App Store product is ignored")
  func appStoreProduct_isIgnored() async {
    let (transactionManager, _) = await makeTransactionManager()
    await dependencyContainer.storeKitManager.setProduct(
      StoreProduct(sk1Product: MockSkProduct(productIdentifier: "app_store_product"), entitlements: [.stub()]),
      forIdentifier: "app_store_product"
    )
    let (paywallVc, finishes) = makePaywall()

    await transactionManager.handleCustomStoreCheckout(
      .complete(productId: "app_store_product", customTransactionId: "txn", shouldDismiss: true),
      paywallViewController: paywallVc
    )

    #expect(await tracked.events.isEmpty)
    #expect(await finishes.waitForResults().isEmpty)
  }
}

private extension RecordingEntitlementsRefresher {
  /// Gives the background refresh time to start.
  func refreshedEntitlementIdsEventually() async -> [Set<String>] {
    for _ in 0..<40 where refreshedEntitlementIds.isEmpty {
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    return refreshedEntitlementIds
  }
}
