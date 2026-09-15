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
  /// A second product in its own group, unlocking a separate entitlement.
  private static let legacyProductId = "com.app.legacy"
  private static let webProductId = "com.app.web"
  private static let coinsProductId = "com.app.coins"

  /// Customer info the way the previous launch would have saved it: one
  /// subscription in `group_A` unlocking `pro`, expiring `expiresIn` from now.
  /// The saved `isActive` flag is always true: when `expiresIn` is negative
  /// that's the stale shape, the flag frozen at the last launch and the date
  /// since passed.
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
      isActive: true,
      expirationDate: expiresAt,
      subscriptionGroupId: "group_A"
    )
    let pro = Entitlement(
      id: "pro",
      isActive: true,
      productIds: [Self.silverProductId, Self.goldProductId],
      latestProductId: Self.silverProductId,
      store: .appStore,
      expiresAt: expiresAt,
      willRenew: willRenew
    )
    return CustomerInfo(subscriptions: [silver], nonSubscriptions: [], entitlements: [pro])
  }

  /// The valid `silver` subscription plus a `legacy` one in `group_B` that was
  /// active when saved but whose expiry has since passed.
  private func savedCustomerInfoWithLapsedSecondSubscription() -> CustomerInfo {
    let valid = savedCustomerInfo(expiresIn: 3600)
    let lapsedAt = Date().addingTimeInterval(-60)
    let legacy = SubscriptionTransaction(
      transactionId: "2",
      productId: Self.legacyProductId,
      purchaseDate: Date().addingTimeInterval(-7200),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: lapsedAt,
      subscriptionGroupId: "group_B"
    )
    let legacyEntitlement = Entitlement(
      id: "legacy",
      isActive: true,
      productIds: [Self.legacyProductId],
      latestProductId: Self.legacyProductId,
      store: .appStore,
      expiresAt: lapsedAt,
      willRenew: true
    )
    // The saved copy is the merged one, so it also carries a web subscription.
    let web = SubscriptionTransaction(
      transactionId: "3",
      productId: Self.webProductId,
      purchaseDate: Date().addingTimeInterval(-600),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: Date().addingTimeInterval(3600),
      store: .stripe
    )
    return CustomerInfo(
      subscriptions: valid.subscriptions + [legacy, web],
      nonSubscriptions: [],
      entitlements: valid.entitlements + [legacyEntitlement]
    )
  }

  /// A web-only subscriber: one Stripe subscription unlocking `pro` on the
  /// silver product, no App Store purchases at all.
  private func savedWebOnlyCustomerInfo() -> CustomerInfo {
    let expiresAt = Date().addingTimeInterval(3600)
    let web = SubscriptionTransaction(
      transactionId: "web-1",
      productId: Self.silverProductId,
      purchaseDate: Date().addingTimeInterval(-600),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: expiresAt,
      store: .stripe
    )
    let pro = Entitlement(
      id: "pro",
      isActive: true,
      productIds: [Self.silverProductId],
      latestProductId: Self.silverProductId,
      store: .stripe,
      expiresAt: expiresAt,
      willRenew: true
    )
    return CustomerInfo(subscriptions: [web], nonSubscriptions: [], entitlements: [pro])
  }

  /// A valid subscription plus one saved active with no expiry at all, which
  /// nothing can show is still current.
  private func savedCustomerInfoWithUndatedSubscription() -> CustomerInfo {
    let valid = savedCustomerInfo(expiresIn: 3600)
    let undated = SubscriptionTransaction(
      transactionId: "4",
      productId: Self.legacyProductId,
      purchaseDate: Date().addingTimeInterval(-7200),
      willRenew: false,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: nil,
      subscriptionGroupId: "group_B"
    )
    return CustomerInfo(
      subscriptions: valid.subscriptions + [undated],
      nonSubscriptions: [],
      entitlements: valid.entitlements
    )
  }

  /// A lifetime purchase: the non-consumable row that unlocks `pro` with no
  /// expiry and `isLifetime` set, plus a consumable the user also bought.
  private func savedLifetimeCustomerInfo() -> CustomerInfo {
    let lifetime = NonSubscriptionTransaction(
      transactionId: "life-1",
      productId: Self.silverProductId,
      purchaseDate: Date().addingTimeInterval(-86_400),
      isConsumable: false,
      isRevoked: false
    )
    let coins = NonSubscriptionTransaction(
      transactionId: "coins-1",
      productId: Self.coinsProductId,
      purchaseDate: Date().addingTimeInterval(-600),
      isConsumable: true,
      isRevoked: false
    )
    let pro = Entitlement(
      id: "pro",
      isActive: true,
      productIds: [Self.silverProductId],
      latestProductId: Self.silverProductId,
      store: .appStore,
      expiresAt: nil,
      isLifetime: true
    )
    return CustomerInfo(subscriptions: [], nonSubscriptions: [lifetime, coins], entitlements: [pro])
  }

  /// Builds a config manager whose receipt loading takes `loadDelay` seconds
  /// on the first call only, so the background refresh that follows does not
  /// keep the test alive. `savedCustomerInfo` stands in for what the previous
  /// launch wrote to disk.
  private func makeHarness(
    container: DependencyContainer? = nil,
    storeKitVersion: SuperwallOptions.StoreKitVersion = .storeKit2,
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
    } + [
      Product(
        name: Self.legacyProductId,
        type: .appStore(.init(id: Self.legacyProductId)),
        id: Self.legacyProductId,
        entitlements: [Entitlement(id: "legacy")]
      )
    ]
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

    let options = SuperwallOptions()
    options.storeKitVersion = storeKitVersion
    let configManager = ConfigManager(
      options: options,
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

  @Test("A second subscription that lapsed since the last launch is restored inactive")
  func restoresLapsedSecondSubscriptionAsInactive() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: savedCustomerInfoWithLapsedSecondSubscription(),
      loadDelay: 2
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    _ = await waitForConfig(harness.configManager, timeout: 1.5)
    #expect(!harness.receipt.didFinishLoad, "test needs config to be published mid-load")

    // The still-valid silver keeps the fast path, but legacy is past its expiry
    // and the web row isn't a device purchase.
    #expect(await harness.receiptManager.getActiveProductIds() == [Self.silverProductId])
    #expect(await harness.receiptManager.isSubscribed(to: Self.legacyProductId) == false)
    #expect(await harness.receiptManager.isSubscribed(to: Self.webProductId) == false)
    let legacyEntitlements = Superwall.shared.entitlements.byProductId(Self.legacyProductId)
    #expect(legacyEntitlements.first?.isActive == false)
    #expect(legacyEntitlements.first?.willRenew == true, "the rest of the saved copy carries over")

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

  @Test("A web-only subscriber takes the fast path with no device purchases seeded")
  func publishesEarlyForWebOnlySubscriber() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: savedWebOnlyCustomerInfo(),
      loadDelay: 2
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    let waited = await waitForConfig(harness.configManager, timeout: 1.5)

    #expect(harness.configManager.config != nil)
    #expect(waited < 1, "config took \(waited)s but StoreKit was still loading")
    #expect(!harness.receipt.didFinishLoad, "test needs config to be published mid-load")

    // Device purchases stay empty, as they are after the read for a web
    // subscriber, while the entitlement map carries the web entitlement.
    #expect(await harness.receiptManager.getActiveProductIds().isEmpty)
    let silverEntitlements = Superwall.shared.entitlements.byProductId(Self.silverProductId)
    #expect(silverEntitlements.first?.isActive == true)
    #expect(silverEntitlements.first?.store == .stripe)

    await fetch.value
    await settle()
  }

  @Test("A developer-granted entitlement takes the fast path with nothing else saved")
  func publishesEarlyForGrantedEntitlement() async {
    // Granted entitlements carry whatever the developer set; usually no expiry.
    dependencyContainer.entitlementsInfo.setGranted([Entitlement(id: "pro")])
    defer { dependencyContainer.entitlementsInfo.setGranted([]) }
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: nil,
      loadDelay: 2
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    let waited = await waitForConfig(harness.configManager, timeout: 1.5)

    #expect(harness.configManager.config != nil)
    #expect(waited < 1, "config took \(waited)s but StoreKit was still loading")
    #expect(!harness.receipt.didFinishLoad, "test needs config to be published mid-load")

    // Every load merges grants back in, so the restore has to carry them too.
    let silverEntitlements = Superwall.shared.entitlements.byProductId(Self.silverProductId)
    #expect(silverEntitlements.first?.id == "pro")
    #expect(silverEntitlements.first?.isActive == true)

    await fetch.value
    await settle()
  }

  @Test("A subscription saved with no expiry is not restored active")
  func doesNotRestoreUndatedSubscriptionAsActive() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: savedCustomerInfoWithUndatedSubscription(),
      loadDelay: 2
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    _ = await waitForConfig(harness.configManager, timeout: 1.5)
    #expect(!harness.receipt.didFinishLoad, "test needs config to be published mid-load")

    // Only the dated, unexpired silver is active. The undated row can't be
    // shown to be current, and the read wouldn't count it either.
    #expect(await harness.receiptManager.getActiveProductIds() == [Self.silverProductId])
    #expect(await harness.receiptManager.isSubscribed(to: Self.legacyProductId) == false)

    await fetch.value
    await settle()
  }

  @Test("A lifetime purchase has no expiry and takes the fast path")
  func publishesEarlyForLifetimePurchase() async {
    let harness = makeHarness(
      isSubscribed: true,
      savedCustomerInfo: savedLifetimeCustomerInfo(),
      loadDelay: 2
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    let waited = await waitForConfig(harness.configManager, timeout: 1.5)

    #expect(harness.configManager.config != nil)
    #expect(waited < 1, "config took \(waited)s but StoreKit was still loading")
    #expect(!harness.receipt.didFinishLoad, "test needs config to be published mid-load")

    // The non-consumable is active, the consumable isn't, same as after the read.
    #expect(await harness.receiptManager.getActiveProductIds() == [Self.silverProductId])
    #expect(await harness.receiptManager.isSubscribed(to: Self.coinsProductId) == false)

    await fetch.value
    await settle()
  }

  @Test("StoreKit 1 has no saved device rows to restore from, so config waits")
  func waitsOnStoreKit1() async {
    let harness = makeHarness(
      storeKitVersion: .storeKit1,
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

  @Test("Saved entitlement still flagged active but past its expiry: config waits")
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

  @Test("An active status on disk with a blank saved customer info is not enough")
  func waitsWithBlankSavedCustomerInfo() async {
    // `Superwall.init` persists `.blank()` before the first read, so this is
    // the real first-launch shape; the harness stores it for a nil input.
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

  @Test("A purchase controller takes the fast path too")
  func publishesEarlyWithExternalPurchaseController() async {
    let controllerContainer = DependencyContainer(purchaseController: MockPurchaseController())
    let harness = makeHarness(
      container: controllerContainer,
      isSubscribed: true,
      savedCustomerInfo: savedCustomerInfo(expiresIn: 3600),
      loadDelay: 2
    )

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    let waited = await waitForConfig(harness.configManager, timeout: 1.5)

    #expect(harness.configManager.config != nil)
    #expect(waited < 1, "config took \(waited)s but StoreKit was still loading")
    #expect(!harness.receipt.didFinishLoad)

    await fetch.value
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
