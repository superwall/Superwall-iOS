//
//  ConfigManagerEarlyPublishTests.swift
//  SuperwallKitTests
//
// A subscriber with a cached config still waited on this launch's StoreKit read
// before `configState` was published, so every `register` call at cold launch
// stalled for as long as that read took. When the customer info saved by the
// previous launch proves the user is entitled through a date that hasn't
// arrived yet, config is now published first and the in-memory purchase state
// is rebuilt from the saved copy until the read lands.
//
// swiftlint:disable all

import Foundation
@testable import SuperwallKit
import Testing

@Suite(.serialized)
struct ConfigManagerEarlyPublishTests {
  /// Held for the lifetime of each test: the managers keep `unowned`
  /// references to the container.
  let dependencyContainer = DependencyContainer()

  private struct Harness {
    let storage: StorageMock
    let configManager: ConfigManager
    let receiptManager: ReceiptManager
    let receipt: SlowReceiptManagerType
    /// Kept alive: other container members hold `unowned` references to the
    /// original receipt manager and to the products manager.
    let originalReceiptManager: ReceiptManager
    let productsManager: ProductsManager
    /// Kept alive: `ConfigManager` holds these `unowned`.
    let network: NetworkMock
    let deviceHelper: DeviceHelperMock
  }

  private static let silverProductId = "com.app.silver"
  private static let goldProductId = "com.app.gold"

  /// Customer info the way the previous launch would have saved it: one active
  /// subscription in `group_A` unlocking `pro`, expiring `expiresIn` from now.
  private func savedCustomerInfo(expiresIn: TimeInterval, willRenew: Bool = false) -> CustomerInfo {
    let expiresAt = Date().addingTimeInterval(expiresIn)
    let silver = SubscriptionTransaction(
      transactionId: "1",
      productId: Self.silverProductId,
      purchaseDate: Date().addingTimeInterval(-3600),
      willRenew: willRenew,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: expiresIn > 0,
      expirationDate: expiresAt,
      subscriptionGroupId: "group_A"
    )
    let pro = Entitlement(
      id: "pro",
      isActive: expiresIn > 0,
      productIds: [Self.silverProductId, Self.goldProductId],
      latestProductId: Self.silverProductId,
      store: .appStore,
      expiresAt: expiresAt,
      willRenew: willRenew
    )
    return CustomerInfo(subscriptions: [silver], nonSubscriptions: [], entitlements: [pro])
  }

  /// Builds a config manager whose receipt loading takes `loadDelay` seconds
  /// on the first call only, so the background refresh that follows does not
  /// keep the test alive. `savedCustomerInfo` stands in for what the previous
  /// launch wrote to disk.
  private func makeHarness(
    container: DependencyContainer? = nil,
    isSubscribed: Bool,
    savedCustomerInfo: CustomerInfo?,
    loadDelay: TimeInterval
  ) -> Harness {
    let dependencyContainer = container ?? self.dependencyContainer
    let storage = StorageMock()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let deviceHelper = DeviceHelperMock(
      api: dependencyContainer.api,
      storage: storage,
      network: network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer
    )

    let receipt = SlowReceiptManagerType(loadDelay: loadDelay)
    let productsFetcher = ProductsFetcherSK1Mock(
      productCompletionResult: .success([]),
      entitlementsInfo: dependencyContainer.entitlementsInfo
    )
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: productsFetcher
    )
    let originalReceiptManager: ReceiptManager = dependencyContainer.receiptManager
    let receiptManager = ReceiptManager(
      storeKitVersion: .storeKit2,
      shouldBypassAppTransactionCheck: true,
      productsManager: productsManager,
      receiptManager: receipt,
      receiptDelegate: nil,
      factory: dependencyContainer,
      storage: storage
    )
    dependencyContainer.receiptManager = receiptManager

    // The config knows both products and the entitlement they unlock; the
    // saved customer info says which is active.
    let products = [Self.silverProductId, Self.goldProductId].map {
      Product(name: $0, type: .appStore(.init(id: $0)), id: $0, entitlements: [Entitlement(id: "pro")])
    }
    let cachedConfig: Config = .stub()
      .setting(\.buildId, to: "cached_123")
      .setting(\.featureFlags, to: .stub())
      .setting(\.products, to: products)
    storage.save(cachedConfig, forType: LatestConfig.self)

    if isSubscribed {
      storage.save(SubscriptionStatus.active([.stub()]), forType: SubscriptionStatusKey.self)
    } else {
      storage.save(SubscriptionStatus.inactive, forType: SubscriptionStatusKey.self)
    }
    storage.save(savedCustomerInfo ?? .blank(), forType: LatestCustomerInfo.self)

    let enrichment = Enrichment(
      user: JSON(["test_user_key": "test_user_value"]),
      device: JSON(["test_device_key": "test_device_value"])
    )
    storage.save(enrichment, forType: LatestEnrichment.self)

    let newConfig: Config = .stub()
      .setting(\.buildId, to: "fresh_456")
    network.configReturnValue = .success(newConfig)

    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    dependencyContainer.configManager = configManager

    return Harness(
      storage: storage,
      configManager: configManager,
      receiptManager: receiptManager,
      receipt: receipt,
      originalReceiptManager: originalReceiptManager,
      productsManager: productsManager,
      network: network,
      deviceHelper: deviceHelper
    )
  }

  /// Polls until `configState` holds a config or `timeout` passes. Returns the
  /// seconds it waited.
  private func waitForConfig(
    _ configManager: ConfigManager,
    timeout: TimeInterval
  ) async -> TimeInterval {
    let start = Date()
    while configManager.config == nil, Date().timeIntervalSince(start) < timeout {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return Date().timeIntervalSince(start)
  }

  private func settle() async {
    // Let the background refresh finish before the container goes away.
    try? await Task.sleep(nanoseconds: 300_000_000)
  }

  @Test("Saved entitlement still valid: config is published before StoreKit finishes")
  func publishesBeforeStoreKitWhenSavedEntitlementIsValid() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: savedCustomerInfo(expiresIn: 3600),
      loadDelay: 2
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    let waited = await waitForConfig(harness.configManager, timeout: 1.5)

    #expect(harness.configManager.config?.buildId == "cached_123")
    #expect(waited < 1, "config took \(waited)s but StoreKit was still loading")
    #expect(harness.receipt.didStartLoad, "purchases load must still be kicked off")
    #expect(!harness.receipt.didFinishLoad, "config was published only after StoreKit finished")

    await fetch.value
    #expect(harness.receipt.didFinishLoad, "fetchConfiguration still waits for the purchases load")
    await settle()
  }

  @Test("While StoreKit loads, purchase state comes from the saved customer info")
  func restoresPurchaseStateFromSavedCustomerInfo() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: savedCustomerInfo(expiresIn: 3600, willRenew: false),
      loadDelay: 2
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    _ = await waitForConfig(harness.configManager, timeout: 1.5)
    #expect(!harness.receipt.didFinishLoad, "test needs config to be published mid-load")

    // Active products for audience filters.
    #expect(await harness.receiptManager.getActiveProductIds() == [Self.silverProductId])
    #expect(await harness.receiptManager.isSubscribed(to: Self.silverProductId))

    // The product-to-entitlement map paywall products are built from, carrying
    // the saved willRenew that audience filters read.
    let silverEntitlements = Superwall.shared.entitlements.byProductId(Self.silverProductId)
    #expect(silverEntitlements.map(\.id) == ["pro"])
    #expect(silverEntitlements.first?.willRenew == false)
    #expect(silverEntitlements.first?.isActive == true)

    await fetch.value
    await settle()
  }

  @Test("Trial eligibility waits for the purchases load that config no longer waits for")
  func trialEligibilityWaitsForInitialPurchasesLoad() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: savedCustomerInfo(expiresIn: 3600),
      loadDelay: 1
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    _ = await waitForConfig(harness.configManager, timeout: 1.5)
    #expect(!harness.receipt.didFinishLoad, "test needs config to be published mid-load")

    let gold = StoreProduct(
      sk1Product: MockSkProduct(
        productIdentifier: Self.goldProductId,
        subscriptionGroupIdentifier: "group_A"
      )
    )
    _ = await dependencyContainer.isFreeTrialAvailable(for: gold)
    #expect(harness.receipt.didFinishLoad, "eligibility was answered before the load finished")

    await fetch.value
    await settle()
  }

  @Test("Saved entitlement expired: purchases still load before config is published")
  func waitsWhenSavedEntitlementHasExpired() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: savedCustomerInfo(expiresIn: -60),
      loadDelay: 1
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    let waited = await waitForConfig(harness.configManager, timeout: 0.5)

    #expect(harness.configManager.config == nil, "config was published after \(waited)s, before purchases loaded")

    await fetch.value
    #expect(harness.receipt.didFinishLoad)
    #expect(harness.configManager.config != nil)
    await settle()
  }

  @Test("An active status on disk with no saved customer info is not enough")
  func waitsWithoutSavedCustomerInfo() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: nil,
      loadDelay: 1
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    _ = await waitForConfig(harness.configManager, timeout: 0.5)

    #expect(harness.configManager.config == nil)

    await fetch.value
    #expect(harness.configManager.config != nil)
    await settle()
  }

  @Test("Unknown subscriber: purchases still load before config is published")
  func syncPathStillLoadsPurchasesBeforePublishing() async {
    let harness = makeHarness(
      isSubscribed: false,
      savedCustomerInfo: savedCustomerInfo(expiresIn: 3600),
      loadDelay: 1
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    _ = await waitForConfig(harness.configManager, timeout: 0.5)

    #expect(harness.configManager.config == nil)

    await fetch.value
    #expect(harness.receipt.didFinishLoad)
    #expect(harness.configManager.config != nil)
    await settle()
  }

  @Test("With a purchase controller the status isn't ours to assume, so config waits")
  func waitsWithExternalPurchaseController() async {
    let controllerContainer = DependencyContainer(purchaseController: MockPurchaseController())
    let harness = makeHarness(
      container: controllerContainer,
      isSubscribed: true,
      savedCustomerInfo: savedCustomerInfo(expiresIn: 3600),
      loadDelay: 1
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    _ = await waitForConfig(harness.configManager, timeout: 0.5)

    #expect(harness.configManager.config == nil)

    await fetch.value
    #expect(harness.configManager.config != nil)
    await settle()
  }
}

/// A `ReceiptManagerType` whose first `loadPurchases` sleeps, standing in for a
/// StoreKit read on a weak network.
private final class SlowReceiptManagerType: ReceiptManagerType, @unchecked Sendable {
  let loadsSubscriptionGroupsFromProducts = false
  private let loadDelay: TimeInterval
  private(set) var didStartLoad = false
  private(set) var didFinishLoad = false
  var purchases: Set<Purchase> = []
  var transactionReceipts: [TransactionReceipt] = []
  var latestSubscriptionPeriodType: LatestSubscription.PeriodType?
  var latestSubscriptionWillAutoRenew: Bool?
  var latestSubscriptionState: LatestSubscription.State?

  init(loadDelay: TimeInterval) {
    self.loadDelay = loadDelay
  }

  func loadIntroOfferEligibility(forProducts _: Set<StoreProduct>) async {}

  func seedPurchases(_ purchases: Set<Purchase>) async {
    self.purchases = purchases
  }

  func loadPurchases(serverEntitlementsByProductId _: [String: Set<Entitlement>]) async -> PurchaseSnapshot {
    let isFirstLoad = !didStartLoad
    didStartLoad = true
    if isFirstLoad {
      try? await Task.sleep(nanoseconds: UInt64(loadDelay * 1_000_000_000))
    }
    didFinishLoad = true
    purchases = []
    return PurchaseSnapshot(
      purchases: [],
      customerInfo: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    )
  }

  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool {
    return true
  }
}
