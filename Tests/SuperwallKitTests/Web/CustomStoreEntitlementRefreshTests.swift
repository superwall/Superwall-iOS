//
//  CustomStoreEntitlementRefreshTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 2026-10-17.
//
// swiftlint:disable all

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

  @Test("The throttled poll still skips apps without a web2app config")
  func pollWebEntitlements_withoutWeb2AppConfig_skips() async {
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let network = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    network.getEntitlementsResponse = entitlementsResponse([])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    await redeemer.pollWebEntitlements()

    #expect(network.getEntitlementsCallCount == 0)
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

    let customerInfo = await superwall.refreshCustomerInfo()

    #expect(network.getEntitlementsCallCount == 1)
    #expect(customerInfo.entitlements.map(\.id) == ["pro"])
    #expect(superwall.customerInfo.entitlements.map(\.id) == ["pro"])
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

    let customerInfo = await superwall.refreshCustomerInfo()

    #expect(network.getEntitlementsCallCount == 0)
    #expect(customerInfo == testModeCustomerInfo)
  }
}
