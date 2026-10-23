//
//  CustomStoreEntitlementRefreshTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 2026-10-17.
//
// swiftlint:disable all

import Combine
import Foundation
import Testing
@testable import SuperwallKit

/// Records the custom purchase refreshes `TransactionManager` starts.
private actor EntitlementsRefresherMock: CustomPurchaseEntitlementsRefreshing {
  private(set) var refreshedEntitlementIds: [Set<String>] = []

  func refreshEntitlementsAfterCustomPurchase(expecting entitlementIds: Set<String>) async {
    refreshedEntitlementIds.append(entitlementIds)
  }
}

/// Tests for refreshing entitlements after custom store purchases, tagging their
/// transaction events and the public `refreshCustomerInfo()` API.
@Suite(.serialized)
struct CustomStoreEntitlementRefreshTests {
  let dependencyContainer = DependencyContainer()

  init() {
    clearEntitlementsState()
  }

  private func clearEntitlementsState() {
    dependencyContainer.storage.delete(LatestRedeemResponse.self)
    dependencyContainer.storage.delete(LastWebEntitlementsFetchDate.self)
    dependencyContainer.storage.delete(LatestDeviceCustomerInfo.self)
    dependencyContainer.storage.delete(PendingStripeCheckoutPollStorage.self)
  }

  // MARK: - Helpers

  private func makeCustomStoreProduct(
    id: String = "custom_prod_1",
    entitlementIds: [String] = ["pro"]
  ) -> StoreProduct {
    let superwallProduct = SuperwallProduct(
      object: "product",
      identifier: id,
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
      entitlements: Set(entitlementIds.map { Entitlement(id: $0, type: .serviceLevel, isActive: false) })
    )
    return StoreProduct(customProduct: apiProduct)
  }

  private func makeAppStoreProduct() -> StoreProduct {
    return StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: "app_store_product"),
      entitlements: [.stub()]
    )
  }

  private func makeTransactionManager(
    refresher: CustomPurchaseEntitlementsRefreshing
  ) -> TransactionManager {
    return TransactionManager(
      storeKitManager: dependencyContainer.storeKitManager,
      receiptManager: dependencyContainer.receiptManager,
      purchaseController: dependencyContainer.purchaseController,
      placementsQueue: dependencyContainer.placementsQueue,
      purchaseManager: dependencyContainer.purchaseManager,
      productsManager: dependencyContainer.productsManager,
      entitlementsRefresher: refresher,
      factory: dependencyContainer
    )
  }

  private func makeRedeemer(
    network: NetworkMock,
    superwall: Superwall,
    refreshDelaysNs: [UInt64] = [0, 0, 0]
  ) -> WebEntitlementRedeemer {
    return WebEntitlementRedeemer(
      network: network,
      storage: dependencyContainer.storage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      customPurchaseRefreshDelaysNs: refreshDelaysNs,
      superwall: superwall
    )
  }

  private func entitlementsResponse(_ entitlements: [Entitlement]) -> EntitlementsResponse {
    return EntitlementsResponse(
      customerInfo: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: entitlements)
    )
  }

  private func turnOnTestMode() {
    var options = SuperwallOptions()
    options.testModeBehavior = .always
    dependencyContainer.testModeManager.evaluateTestMode(config: .stub(), options: options)
  }

  // MARK: - Post-purchase refresh trigger

  @Test("A custom product purchase starts an entitlements refresh for its entitlements")
  func customProductPurchase_startsRefresh() async {
    let refresher = EntitlementsRefresherMock()
    let transactionManager = makeTransactionManager(refresher: refresher)
    let product = makeCustomStoreProduct(entitlementIds: ["pro", "gold"])

    let task = transactionManager.refreshEntitlementsAfterCustomPurchaseIfNeeded(for: product)
    #expect(task != nil)
    await task?.value

    #expect(await refresher.refreshedEntitlementIds == [["pro", "gold"]])
  }

  @Test("An App Store product purchase doesn't start an entitlements refresh")
  func appStoreProductPurchase_doesNotStartRefresh() async {
    let refresher = EntitlementsRefresherMock()
    let transactionManager = makeTransactionManager(refresher: refresher)

    let task = transactionManager.refreshEntitlementsAfterCustomPurchaseIfNeeded(for: makeAppStoreProduct())

    #expect(task == nil)
    #expect(await refresher.refreshedEntitlementIds.isEmpty)
  }

  @Test("A custom product purchase in test mode doesn't start an entitlements refresh")
  func customProductPurchase_inTestMode_doesNotStartRefresh() async {
    turnOnTestMode()
    let refresher = EntitlementsRefresherMock()
    let transactionManager = makeTransactionManager(refresher: refresher)

    let task = transactionManager.refreshEntitlementsAfterCustomPurchaseIfNeeded(for: makeCustomStoreProduct())

    #expect(task == nil)
    #expect(await refresher.refreshedEntitlementIds.isEmpty)
  }

  @Test("didPurchase of a custom product refreshes entitlements without blocking")
  func didPurchase_customProduct_refreshesEntitlements() async {
    let refresher = EntitlementsRefresherMock()
    let transactionManager = makeTransactionManager(refresher: refresher)
    let product = makeCustomStoreProduct()

    await transactionManager.prepareToPurchase(
      product: product,
      purchaseSource: .purchaseFunc(product)
    )
    await transactionManager.didPurchase()

    var attempts = 0
    while await refresher.refreshedEntitlementIds.isEmpty && attempts < 30 {
      try? await Task.sleep(nanoseconds: 100_000_000)
      attempts += 1
    }
    #expect(await refresher.refreshedEntitlementIds == [["pro"]])
    await dependencyContainer.makePurchasingCoordinator().reset()
  }

  // MARK: - Retry policy

  @Test("The post-purchase refresh stops once the purchased entitlements are active")
  func refreshAfterCustomPurchase_stopsOnSuccess() async {
    defer { clearEntitlementsState() }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    // The developer's server hasn't reported the purchase on the first fetch.
    network.getEntitlementsResponses = [
      entitlementsResponse([Entitlement(id: "pro", isActive: false, store: .custom)]),
      entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)]),
      entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    ]
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    await redeemer.refreshEntitlementsAfterCustomPurchase(expecting: ["pro"])

    #expect(network.getEntitlementsCallCount == 2)
    let saved = dependencyContainer.storage.get(LatestRedeemResponse.self)
    #expect(saved?.customerInfo.entitlements.first?.isActive == true)
  }

  @Test("The post-purchase refresh gives up after the last attempt")
  func refreshAfterCustomPurchase_givesUpAfterAttempts() async {
    defer { clearEntitlementsState() }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([
      Entitlement(id: "pro", isActive: false, store: .custom)
    ])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    await redeemer.refreshEntitlementsAfterCustomPurchase(expecting: ["pro"])

    #expect(network.getEntitlementsCallCount == 3)
  }

  @Test("The post-purchase refresh retries failed fetches")
  func refreshAfterCustomPurchase_retriesFailedFetches() async {
    defer { clearEntitlementsState() }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    // No response configured, so every fetch throws.
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    await redeemer.refreshEntitlementsAfterCustomPurchase(expecting: ["pro"])

    #expect(network.getEntitlementsCallCount == 3)
  }

  // MARK: - Presented paywall

  /// Presents a paywall selling a product that unlocks `pro`, and returns the
  /// delegate that records tracked events.
  @MainActor
  private func presentPaywallUnlockingPro(superwall: Superwall) async -> MockSuperwallDelegate {
    let cache = dependencyContainer.paywallManager.cache
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let entitlement = Entitlement(id: "pro", isActive: true)
    let product = Product(
      name: "Custom Product",
      type: .appStore(.init(id: "custom_prod_1")),
      id: "custom_prod_1",
      entitlements: [entitlement]
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: Paywall.stub().setting(\.products, to: [product]),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: cache,
      paywallArchiveManager: nil,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    cache.save(paywallVc, forKey: "key")
    cache.activePaywallVcKey = "key"
    dependencyContainer.entitlementsInfo.entitlementsByProductId["custom_prod_1"] = [entitlement]

    let delegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = delegate
    superwall.delegate = delegate
    dependencyContainer.delegateAdapter = delegateAdapter
    return delegate
  }

  private func clearPresentedPaywall() {
    dependencyContainer.paywallManager.cache.activePaywallVcKey = nil
    dependencyContainer.entitlementsInfo.entitlementsByProductId["custom_prod_1"] = nil
  }

  @Test("The post-purchase refresh doesn't turn the purchase into a restore of the open paywall")
  func refreshAfterCustomPurchase_paywallOpen_doesNotRestore() async {
    defer {
      clearEntitlementsState()
      clearPresentedPaywall()
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let delegate = await presentPaywallUnlockingPro(superwall: superwall)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    await redeemer.refreshEntitlementsAfterCustomPurchase(expecting: ["pro"])

    let events = delegate.eventsReceived.map { $0.backingData.objcEvent }
    #expect(!events.contains(SuperwallEventObjc.restoreComplete))
    #expect(superwall.paywallViewController != nil)
    #expect(dependencyContainer.entitlementsInfo.web.map(\.id) == ["pro"])
  }

  @Test("A poll that unlocks the open paywall's entitlements still restores it")
  func poll_paywallOpen_restores() async {
    defer {
      clearEntitlementsState()
      clearPresentedPaywall()
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let delegate = await presentPaywallUnlockingPro(superwall: superwall)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    await redeemer.pollWebEntitlements()

    let events = delegate.eventsReceived.map { $0.backingData.objcEvent }
    #expect(events.contains(SuperwallEventObjc.restoreComplete))
  }

  @Test("A poll during a purchase doesn't turn it into a restore of the open paywall")
  func poll_paywallOpen_purchaseInProgress_doesNotRestore() async {
    let coordinator = dependencyContainer.makePurchasingCoordinator()
    defer {
      clearEntitlementsState()
      clearPresentedPaywall()
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let delegate = await presentPaywallUnlockingPro(superwall: superwall)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    let redeemer = makeRedeemer(network: network, superwall: superwall)
    // The user is paying in the custom store's checkout and comes back to the app.
    let product = makeCustomStoreProduct()
    await coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)

    await redeemer.pollWebEntitlements()
    await coordinator.reset()

    let events = delegate.eventsReceived.map { $0.backingData.objcEvent }
    #expect(!events.contains(SuperwallEventObjc.restoreComplete))
    #expect(superwall.paywallViewController != nil)
    #expect(dependencyContainer.entitlementsInfo.web.map(\.id) == ["pro"])
  }

  // MARK: - Apps without web2app config

  @Test("Refreshing fetches entitlements without a web2app config or max age")
  func refreshWebEntitlements_withoutWeb2AppConfig_fetches() async {
    defer { clearEntitlementsState() }
    #expect(dependencyContainer.makeEntitlementsMaxAge() == nil)
    // A fetch just happened, so a max-age throttle would skip this one.
    dependencyContainer.storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    let customEntitlement = Entitlement(id: "pro", isActive: true, store: .custom)
    network.getEntitlementsResponse = entitlementsResponse([customEntitlement])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    let customerInfo = await redeemer.refreshWebEntitlements()

    #expect(network.getEntitlementsCallCount == 1)
    #expect(customerInfo?.entitlements == [customEntitlement])
    let saved = dependencyContainer.storage.get(LatestRedeemResponse.self)
    #expect(saved?.customerInfo.entitlements == [customEntitlement])
    #expect(dependencyContainer.entitlementsInfo.web.map(\.id) == ["pro"])
  }

  // MARK: - Launch and foreground polling

  private func web2AppConfig(entitlementsMaxAge: Seconds) -> Config {
    return Config
      .stub()
      .setting(
        \.web2appConfig,
        to: .init(entitlementsMaxAge: entitlementsMaxAge, restoreAccessURL: URL(string: "https://superwall.com")!)
      )
  }

  /// Runs the throttled poll, as the foreground and config refresh do, with
  /// entitlements last fetched `lastFetchAge` seconds ago (`nil`: never).
  private func pollCallCount(
    lastFetchAge: Seconds?,
    config: Config? = nil,
    isFirstTime: Bool = false
  ) async -> Int {
    defer { clearEntitlementsState() }
    if let lastFetchAge = lastFetchAge {
      dependencyContainer.storage.save(
        Date().addingTimeInterval(-lastFetchAge),
        forType: LastWebEntitlementsFetchDate.self
      )
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    await redeemer.pollWebEntitlements(config: config, isFirstTime: isFirstTime)

    return network.getEntitlementsCallCount
  }

  @Test("The default max age is 15 minutes")
  func defaultEntitlementsMaxAge_is15Minutes() {
    #expect(WebEntitlementRedeemer.defaultEntitlementsMaxAge == 15 * 60)
  }

  @Test("Without a web2app config, a poll fetches when entitlements are older than 15 minutes")
  func poll_withoutWeb2AppConfig_fetchesWhenStale() async {
    #expect(dependencyContainer.makeEntitlementsMaxAge() == nil)
    #expect(await pollCallCount(lastFetchAge: 16 * 60) == 1)
  }

  @Test("Without a web2app config, a poll skips when entitlements are fresher than 15 minutes")
  func poll_withoutWeb2AppConfig_skipsWhenFresh() async {
    #expect(await pollCallCount(lastFetchAge: 14 * 60) == 0)
  }

  @Test("Without a web2app config, a poll fetches when entitlements were never fetched")
  func poll_withoutWeb2AppConfig_freshInstall_fetches() async {
    #expect(await pollCallCount(lastFetchAge: nil) == 1)
  }

  @Test("The poll after the first config fetches even when entitlements are fresh")
  func poll_firstConfig_fetchesWhenFresh() async {
    #expect(await pollCallCount(lastFetchAge: 60, config: .stub(), isFirstTime: true) == 1)
  }

  @Test("With a web2app config, the server's max age applies instead of the default")
  func poll_withWeb2AppConfig_usesServerMaxAge() async {
    // Shorter than the default: fetches after 5 minutes.
    #expect(await pollCallCount(lastFetchAge: 5 * 60, config: web2AppConfig(entitlementsMaxAge: 60)) == 1)
    // Longer than the default: still fresh after 20 minutes.
    #expect(await pollCallCount(lastFetchAge: 20 * 60, config: web2AppConfig(entitlementsMaxAge: 3_600)) == 0)
  }

  @Test("A poll in test mode doesn't fetch")
  func poll_inTestMode_skips() async {
    turnOnTestMode()
    #expect(await pollCallCount(lastFetchAge: nil) == 0)
    #expect(await pollCallCount(lastFetchAge: 60, config: .stub(), isFirstTime: true) == 0)
  }

  @Test("Concurrent polls share one fetch")
  func poll_concurrent_sharesOneFetch() async {
    defer { clearEntitlementsState() }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    network.getEntitlementsDelayNs = 200_000_000
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    async let first: Void = redeemer.pollWebEntitlements()
    async let second: Void = redeemer.pollWebEntitlements()
    _ = await (first, second)

    #expect(network.getEntitlementsCallCount == 1)
  }

  @Test("The poll after the first config doesn't join a poll already in flight")
  func poll_firstConfig_doesNotJoinInFlightPoll() async {
    defer { clearEntitlementsState() }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    network.getEntitlementsDelaysNs = [300_000_000, 0]
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    let foregroundPoll = Task { await redeemer.pollWebEntitlements() }
    try? await Task.sleep(nanoseconds: 50_000_000)
    await redeemer.pollWebEntitlements(config: .stub(), isFirstTime: true)
    await foregroundPoll.value

    #expect(network.getEntitlementsCallCount == 2)
  }

  // MARK: - Overlapping fetches

  @Test("A fetch that finishes after a newer one doesn't overwrite its entitlements")
  func refresh_staleResponseArrivingLast_isDropped() async {
    defer { clearEntitlementsState() }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    // The older fetch started before the server knew about the purchase, and is slow.
    network.getEntitlementsResponses = [
      entitlementsResponse([Entitlement(id: "pro", isActive: false, store: .custom)]),
      entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    ]
    network.getEntitlementsDelaysNs = [300_000_000, 0]
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    let olderFetch = Task { await redeemer.refreshWebEntitlements() }
    try? await Task.sleep(nanoseconds: 50_000_000)
    let newerInfo = await redeemer.refreshWebEntitlements()
    let olderInfo = await olderFetch.value

    #expect(newerInfo?.entitlements.first?.isActive == true)
    // The older fetch hands back the newer customer info instead of its own.
    #expect(olderInfo?.entitlements.first?.isActive == true)
    let saved = dependencyContainer.storage.get(LatestRedeemResponse.self)
    #expect(saved?.customerInfo.entitlements.first?.isActive == true)
    #expect(dependencyContainer.entitlementsInfo.web.map(\.id) == ["pro"])
  }

  @Test("A refresh that changes nothing doesn't republish customerInfo")
  func refresh_unchangedResponse_doesNotRepublishCustomerInfo() async {
    defer { clearEntitlementsState() }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true, store: .custom)])
    let redeemer = makeRedeemer(network: network, superwall: superwall)
    await redeemer.refreshWebEntitlements()

    var publishCount = 0
    let cancellable = superwall.$customerInfo
      .dropFirst()
      .sink { _ in publishCount += 1 }
    await redeemer.refreshWebEntitlements()
    cancellable.cancel()

    #expect(network.getEntitlementsCallCount == 2)
    #expect(publishCount == 0)
  }

  // MARK: - Transaction store

  @Test("transaction_complete for a custom product reports the CUSTOM store")
  func transactionComplete_customProduct_storeIsCustom() async {
    let product = makeCustomStoreProduct()
    let customTransaction = CustomStoreTransaction(
      customTransactionId: UUID().uuidString,
      productIdentifier: product.productIdentifier,
      purchaseDate: Date()
    )
    let transaction = await dependencyContainer.makeStoreTransaction(from: customTransaction)

    let result = await Superwall.shared.track(
      InternalSuperwallEvent.Transaction(
        state: .complete(product, transaction, .subscriptionStart),
        paywallInfo: .stub(),
        product: product,
        transaction: transaction,
        source: .internal,
        isObserved: false,
        storeKitVersion: .storeKit2
      )
    )

    #expect(result.parameters.audienceFilterParams["$store"] as? String == "CUSTOM")
  }

  @Test("transaction_complete for an App Store product reports the APP_STORE store")
  func transactionComplete_appStoreProduct_storeIsAppStore() async {
    let product = makeAppStoreProduct()
    let skTransaction = MockSKPaymentTransaction(state: .purchased)
    let transaction = await dependencyContainer.makeStoreTransaction(from: skTransaction)

    let result = await Superwall.shared.track(
      InternalSuperwallEvent.Transaction(
        state: .complete(product, transaction, .subscriptionStart),
        paywallInfo: .stub(),
        product: product,
        transaction: transaction,
        source: .internal,
        isObserved: false,
        storeKitVersion: .storeKit1
      )
    )

    #expect(result.parameters.audienceFilterParams["$store"] as? String == "APP_STORE")
  }

  @Test("An explicit store overrides the product's store")
  func transaction_explicitStore_overridesProductStore() async {
    let product = makeCustomStoreProduct()

    let result = await Superwall.shared.track(
      InternalSuperwallEvent.Transaction(
        state: .start(product),
        paywallInfo: .stub(),
        product: product,
        transaction: nil,
        source: .internal,
        isObserved: false,
        storeKitVersion: nil,
        store: .stripe
      )
    )

    #expect(result.parameters.audienceFilterParams["$store"] as? String == "STRIPE")
  }

  // MARK: - Public refresh API

  @Test("refreshCustomerInfo fetches entitlements and returns the updated customer info")
  func refreshCustomerInfo_fetchesAndReturnsUpdatedInfo() async {
    defer { clearEntitlementsState() }
    // Fetched recently, so the regular poll would be throttled.
    dependencyContainer.storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    let customEntitlement = Entitlement(id: "pro", isActive: true, store: .custom)
    network.getEntitlementsResponse = entitlementsResponse([customEntitlement])
    dependencyContainer.webEntitlementRedeemer = makeRedeemer(network: network, superwall: superwall)

    dependencyContainer.configManager.configState.send(.retrieved(.stub()))
    let customerInfo = await superwall.refreshCustomerInfo()

    #expect(network.getEntitlementsCallCount == 1)
    #expect(customerInfo.entitlements.map(\.id) == ["pro"])
    #expect(superwall.customerInfo.entitlements.map(\.id) == ["pro"])
  }

  @Test("refreshCustomerInfo returns new transactions when the entitlements haven't changed")
  func refreshCustomerInfo_unchangedEntitlements_returnsNewTransactions() async {
    defer { clearEntitlementsState() }
    let entitlement = Entitlement(id: "pro", isActive: true, store: .custom)
    dependencyContainer.storage.save(
      RedeemResponse(results: [], customerInfo: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [entitlement])),
      forType: LatestRedeemResponse.self
    )
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let renewal = SubscriptionTransaction(
      transactionId: "renewal_1",
      productId: "custom_prod_1",
      purchaseDate: Date(),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: Date().addingTimeInterval(30 * 24 * 3600),
      store: .custom
    )
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = EntitlementsResponse(
      customerInfo: CustomerInfo(subscriptions: [renewal], nonSubscriptions: [], entitlements: [entitlement])
    )
    dependencyContainer.webEntitlementRedeemer = makeRedeemer(network: network, superwall: superwall)

    dependencyContainer.configManager.configState.send(.retrieved(.stub()))
    let customerInfo = await superwall.refreshCustomerInfo()

    #expect(customerInfo.subscriptions.map(\.transactionId) == ["renewal_1"])
    #expect(superwall.customerInfo.subscriptions.map(\.transactionId) == ["renewal_1"])
  }

  @Test("refreshCustomerInfo doesn't fetch in test mode")
  func refreshCustomerInfo_inTestMode_doesNotFetch() async {
    turnOnTestMode()
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeCustomerInfo = CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    superwall.customerInfo = testModeCustomerInfo
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true)])
    dependencyContainer.webEntitlementRedeemer = makeRedeemer(network: network, superwall: superwall)

    dependencyContainer.configManager.configState.send(.retrieved(.stub()))
    let customerInfo = await superwall.refreshCustomerInfo()

    #expect(network.getEntitlementsCallCount == 0)
    #expect(customerInfo == testModeCustomerInfo)
  }

  @Test("refreshCustomerInfo called before config waits for it to know about test mode")
  func refreshCustomerInfo_beforeConfig_waitsForTestMode() async {
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let testModeCustomerInfo = CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    superwall.customerInfo = testModeCustomerInfo
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([Entitlement(id: "pro", isActive: true)])
    dependencyContainer.webEntitlementRedeemer = makeRedeemer(network: network, superwall: superwall)

    let refresh = Task { await superwall.refreshCustomerInfo() }
    try? await Task.sleep(nanoseconds: 100_000_000)
    // Config arrives and turns test mode on.
    turnOnTestMode()
    dependencyContainer.configManager.configState.send(.retrieved(.stub()))
    _ = await refresh.value

    #expect(network.getEntitlementsCallCount == 0)
  }
}
