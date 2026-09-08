//
//  File.swift
//
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

import Foundation
@testable import SuperwallKit
import Testing

@Suite(.serialized)
struct ConfigManagerTests {
  @Test
  func refreshConfiguration() async {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let newConfig: Config = .stub()
      .setting(\.buildId, to: "123")
    network.configReturnValue = .success(newConfig)

    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )

    let oldConfig: Config = .stub()
      .setting(\.buildId, to: "abc")
    configManager.configState.send(.retrieved(oldConfig))

    await configManager.refreshConfiguration()

    #expect(configManager.config?.buildId == "123")
  }

  @Test
  func configEncodedCorrectly() async {
    let dependencyContainer = DependencyContainer()

    let paywall = Paywall.stub()
      .setting(\.products, to: [.init(name: "abc", type: .appStore(.init(id: "abc")), id: "abc", entitlements: [.stub()])])
    let config: Config = Config(
      buildId: "buildId",
      triggers: [
        .init(
          placementName: "event",
          audiences: [.stub()]
        )
      ],
      paywalls: [paywall],
      logLevel: 2,
      locales: ["fr"],
      appSessionTimeout: 2202,
      featureFlags: .stub(),
      preloadingDisabled: .stub(),
      attribution: .init(appleSearchAds: .init(enabled: true)),
      products: paywall.products
    )
    dependencyContainer.storage.save(config, forType: LatestConfig.self)
    let newConfig = dependencyContainer.storage.get(LatestConfig.self)
    #expect(config == newConfig)
  }

  @Test
  @available(iOS 14.0, *)
  func configWithPrioritizedCampaignIdEncodedCorrectly() async {
    let dependencyContainer = DependencyContainer()

    let paywall = Paywall.stub()
      .setting(\.products, to: [.init(name: "abc", type: .appStore(.init(id: "abc")), id: "abc", entitlements: [.stub()])])
    var config: Config = Config(
      buildId: "buildId",
      triggers: [
        .init(
          placementName: "event",
          audiences: [.stub()]
        )
      ],
      paywalls: [paywall],
      logLevel: 2,
      locales: ["fr"],
      appSessionTimeout: 2202,
      featureFlags: .stub(),
      preloadingDisabled: .stub(),
      attribution: .init(appleSearchAds: .init(enabled: true)),
      products: paywall.products
    )
    config.prioritizedCampaignId = "42"
    dependencyContainer.storage.save(config, forType: LatestConfig.self)
    let newConfig = dependencyContainer.storage.get(LatestConfig.self)
    #expect(config == newConfig)
  }

  // MARK: - Confirm Assignments
  @Test
  func confirmAssignment() async {
    let experimentId = "abc"
    let variantId = "def"
    let variant: Experiment.Variant = .init(id: variantId, type: .treatment, paywallId: "jkl")
    let assignment = Assignment(
      experimentId: experimentId,
      variant: variant,
      isSentToServer: false
    )
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    configManager.postbackAssignment(assignment)

    try? await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

    #expect(network.assignmentsConfirmed)
    #expect(storage.getAssignments().first(where: { $0.experimentId == experimentId })?.variant == variant)
  }

  @Test
  func confirmAssignmentUpdateNewVariant() async {
    let experimentId = "abc"
    let variantId = "def"
    let variant: Experiment.Variant = .init(id: variantId, type: .treatment, paywallId: "jkl")
    let assignment = Assignment(
      experimentId: experimentId,
      variant: variant,
      isSentToServer: false
    )
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    configManager.postbackAssignment(assignment)

    try? await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

    #expect(network.assignmentsConfirmed)
    #expect(storage.getAssignments().first(where: { $0.experimentId == experimentId })?.variant == variant)
  }

  // MARK: - Load Assignments

  @Test
  func loadAssignmentsNoConfig() async {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )

    // When there's no config, getAssignments should block waiting for config
    // Start the task but cancel it after a short delay to verify it doesn't complete
    let task = Task {
      try? await configManager.getAssignments()
    }

    try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
    task.cancel()

    #expect(storage.getAssignments().isEmpty)
  }

  @Test
  func loadAssignmentsNoTriggers() async {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    configManager.configState.send(.retrieved(.stub()
      .setting(\.triggers, to: [])))

    try? await configManager.getAssignments()

    #expect(storage.getAssignments().isEmpty)
  }

  @Test
  func loadAssignmentsSaveAssignmentsFromServer() async {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )

    let variantId = "variantId"
    let experimentId = "experimentId"

    let assignments: [PostbackAssignment] = [
      PostbackAssignment(experimentId: experimentId, variantId: variantId)
    ]
    network.assignments = assignments

    let variantOption: VariantOption = .stub()
      .setting(\.id, to: variantId)
    configManager.configState.send(.retrieved(.stub()
      .setting(\.triggers, to: [
        .stub()
        .setting(\.audiences, to: [
          .stub()
          .setting(\.experiment.id, to: experimentId)
          .setting(\.experiment.variants, to: [
            variantOption
          ])
        ])
      ])
    ))

    try? await configManager.getAssignments()

    try? await Task.sleep(nanoseconds: 1_000_000)

    #expect(storage.getAssignments().first(where: { $0.experimentId == experimentId })?.variant == variantOption.toExperimentVariant())
  }

  // MARK: - Fetch Configuration

  @Test
  func fetchConfigurationAsyncPathSubscribedWithCache() async throws {
    // Given: User is subscribed and has cached config
    let storage = StorageMock()
    let dependencyContainer = DependencyContainer()
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

    let cachedConfig: Config = .stub()
      .setting(\.buildId, to: "cached_123")
      .setting(\.featureFlags, to: .stub())
    storage.save(cachedConfig, forType: LatestConfig.self)

    let activeEntitlements: Set<Entitlement> = [.stub()]
    storage.save(SubscriptionStatus.active(activeEntitlements), forType: SubscriptionStatusKey.self)

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

    // When: fetchConfiguration is called
    await configManager.fetchConfiguration()

    // Then: Should immediately use cached config (async path)
    #expect(configManager.config?.buildId == "cached_123", "Should use cached config immediately")

    // And: Should use cached enrichment immediately
    #expect(deviceHelper.enrichment != nil, "Should use cached enrichment")

    // Note: We don't test the background refresh here to avoid timing issues with deallocated references
    // The background refresh is tested separately in refreshConfiguration test

    // Wait for background tasks to complete before test ends
    try await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
  }

  @Test
  func fetchConfigurationSyncPathNotSubscribed() async {
    // Given: User is not subscribed
    let storage = StorageMock()
    let dependencyContainer = DependencyContainer()
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

    storage.save(SubscriptionStatus.inactive, forType: SubscriptionStatusKey.self)

    let newConfig: Config = .stub()
      .setting(\.buildId, to: "sync_789")
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

    // When: fetchConfiguration is called
    await configManager.fetchConfiguration()

    // Then: Should fetch config synchronously
    #expect(network.getConfigCalled, "Should call network to fetch config")
    #expect(configManager.config?.buildId == "sync_789", "Should use freshly fetched config")

    // Wait for background tasks to complete before test ends
    try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
  }

  @Test
  func fetchConfigurationSyncPathNoCachedConfig() async {
    // Given: No cached config (first launch)
    let storage = StorageMock()
    let dependencyContainer = DependencyContainer()
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

    let newConfig: Config = .stub()
      .setting(\.buildId, to: "first_launch_999")
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

    // When: fetchConfiguration is called
    await configManager.fetchConfiguration()

    // Then: Should fetch config synchronously
    #expect(network.getConfigCalled, "Should call network to fetch config")
    #expect(configManager.config?.buildId == "first_launch_999", "Should use freshly fetched config")

    // Wait for background tasks to complete before test ends
    try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
  }

  @Test
  func fetchConfigurationSyncPathSubscribedButNoCachedConfig() async {
    // Given: User is subscribed but no cached config
    let storage = StorageMock()
    let dependencyContainer = DependencyContainer()
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

    // User is subscribed
    let activeEntitlements: Set<Entitlement> = [.stub()]
    storage.save(SubscriptionStatus.active(activeEntitlements), forType: SubscriptionStatusKey.self)

    let newConfig: Config = .stub()
      .setting(\.buildId, to: "subscribed_no_cache_789")
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

    // When: fetchConfiguration is called
    await configManager.fetchConfiguration()

    // Then: Should fetch config synchronously (no cached config means sync path)
    #expect(network.getConfigCalled, "Should call network to fetch config")
    #expect(configManager.config?.buildId == "subscribed_no_cache_789", "Should use freshly fetched config")

    // Wait for background tasks to complete before test ends
    try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
  }

  @Test
  func fetchConfigurationSyncPathCachedConfigButNotSubscribed() async {
    // Given: Has cached config but user is not subscribed
    let storage = StorageMock()
    let dependencyContainer = DependencyContainer()
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

    // Has cached config
    let cachedConfig: Config = .stub()
      .setting(\.buildId, to: "cached_old")
      .setting(\.featureFlags, to: .stub())
    storage.save(cachedConfig, forType: LatestConfig.self)

    // But user is NOT subscribed
    storage.save(SubscriptionStatus.inactive, forType: SubscriptionStatusKey.self)

    let newConfig: Config = .stub()
      .setting(\.buildId, to: "cached_but_not_subscribed_999")
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

    // When: fetchConfiguration is called
    await configManager.fetchConfiguration()

    // Then: Should fetch config synchronously (not subscribed means sync path)
    #expect(network.getConfigCalled, "Should call network to fetch config")
    #expect(configManager.config?.buildId == "cached_but_not_subscribed_999", "Should use freshly fetched config, not cached")

    // Wait for background tasks to complete before test ends
    try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
  }

  @Test
  func fetchConfigurationFallbackToCachedConfigOnNetworkError() async {
    // Given: Has cached config with enableConfigRefresh feature flag
    let storage = StorageMock()
    let dependencyContainer = DependencyContainer()
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

    // Has cached config with enableConfigRefresh enabled
    let cachedConfig: Config = .stub()
      .setting(\.buildId, to: "cached_fallback_123")
      .setting(\.featureFlags, to: .stub()
        .setting(\.enableConfigRefresh, to: true))
    storage.save(cachedConfig, forType: LatestConfig.self)

    // User is NOT subscribed (sync path)
    storage.save(SubscriptionStatus.inactive, forType: SubscriptionStatusKey.self)

    // Network will fail
    network.configReturnValue = .failure(NetworkError.unknown)

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

    // When: fetchConfiguration is called and network fails
    await configManager.fetchConfiguration()

    // Then: Should fall back to cached config
    #expect(network.getConfigCalled, "Should attempt to call network")
    #expect(configManager.config?.buildId == "cached_fallback_123", "Should fall back to cached config on network error")

    // Wait for background tasks to complete before test ends
    try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
  }
}

// MARK: - Cold-launch StoreKit stall

// Regression tests for a cold-launch stall. A subscriber with a cached config
// took the async config path, so the config itself was available at once, but
// `configState` was not published until `loadPurchasedProducts` finished.
// That call reads StoreKit, which can take 10 to 25 seconds on a weak network.
// Every `register` call waits on `configState`, so gated features froze for
// that long, and features that ran inside the closure were lost if the app
// was killed first.
//
@Suite(.serialized)
struct ConfigManagerStoreKitStallTests {
  /// Held for the lifetime of each test: the managers keep `unowned`
  /// references to the container.
  let dependencyContainer = DependencyContainer()

  private struct Harness {
    let storage: StorageMock
    let configManager: ConfigManager
    let receipt: SlowReceiptManagerType
    /// Kept alive: other container members hold `unowned` references to the
    /// original receipt manager and to the products manager.
    let originalReceiptManager: ReceiptManager
    let productsManager: ProductsManager
    /// Kept alive: `ConfigManager` holds these `unowned`.
    let network: NetworkMock
    let deviceHelper: DeviceHelperMock
  }

  /// Builds a config manager whose receipt loading takes `loadDelay` seconds
  /// on the first call only, so the background refresh that follows does not
  /// keep the test alive.
  private func makeHarness(
    isSubscribed: Bool,
    loadDelay: TimeInterval
  ) -> Harness {
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
    dependencyContainer.receiptManager = ReceiptManager(
      storeKitVersion: .storeKit2,
      shouldBypassAppTransactionCheck: true,
      productsManager: productsManager,
      receiptManager: receipt,
      receiptDelegate: nil,
      factory: dependencyContainer,
      storage: storage
    )

    let cachedConfig: Config = .stub()
      .setting(\.buildId, to: "cached_123")
      .setting(\.featureFlags, to: .stub())
    storage.save(cachedConfig, forType: LatestConfig.self)

    if isSubscribed {
      let activeEntitlements: Set<Entitlement> = [.stub()]
      storage.save(SubscriptionStatus.active(activeEntitlements), forType: SubscriptionStatusKey.self)
    } else {
      storage.save(SubscriptionStatus.inactive, forType: SubscriptionStatusKey.self)
    }

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

  @Test("Subscriber with cached config: config is published before StoreKit finishes")
  func subscriberWithCachedConfigDoesNotWaitForStoreKit() async {
    let harness = makeHarness(isSubscribed: true, loadDelay: 2)

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    let waited = await waitForConfig(harness.configManager, timeout: 1.5)

    #expect(harness.configManager.config?.buildId == "cached_123")
    #expect(waited < 1, "config took \(waited)s but StoreKit was still loading")
    #expect(harness.receipt.didStartLoad, "purchases load must still be kicked off")
    #expect(!harness.receipt.didFinishLoad, "config was published only after StoreKit finished")

    await fetch.value
    #expect(harness.receipt.didFinishLoad, "fetchConfiguration still waits for the purchases load")

    // Let the background refresh finish before the container goes away.
    try? await Task.sleep(nanoseconds: 300_000_000)
  }

  @Test("Unknown subscriber: purchases still load before config is published")
  func syncPathStillLoadsPurchasesBeforePublishing() async {
    let harness = makeHarness(isSubscribed: false, loadDelay: 1)

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    let waited = await waitForConfig(harness.configManager, timeout: 0.5)

    #expect(harness.configManager.config == nil, "sync path published config after \(waited)s, before purchases loaded")

    await fetch.value
    #expect(harness.receipt.didFinishLoad)
    #expect(harness.configManager.config != nil)

    try? await Task.sleep(nanoseconds: 300_000_000)
  }

  @Test("Trial eligibility waits for the purchases load that config no longer waits for")
  func trialEligibilityWaitsForInitialPurchasesLoad() async {
    let harness = makeHarness(isSubscribed: true, loadDelay: 1)

    let fetch = Task { await harness.configManager.fetchConfiguration() }
    _ = await waitForConfig(harness.configManager, timeout: 1.5)
    #expect(!harness.receipt.didFinishLoad, "test needs config to be published mid-load")

    let product = StoreProduct(
      sk1Product: MockSkProduct(
        productIdentifier: "com.app.gold",
        subscriptionGroupIdentifier: "group_A"
      )
    )
    _ = await dependencyContainer.isFreeTrialAvailable(for: product)
    #expect(harness.receipt.didFinishLoad, "eligibility was answered before active subscription groups were known")

    await fetch.value
    try? await Task.sleep(nanoseconds: 300_000_000)
  }
}

/// A `ReceiptManagerType` whose first `loadPurchases` sleeps, standing in for a
/// StoreKit read on a weak network.
private final class SlowReceiptManagerType: ReceiptManagerType, @unchecked Sendable {
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

  func loadPurchases(serverEntitlementsByProductId _: [String: Set<Entitlement>]) async -> PurchaseSnapshot {
    let isFirstLoad = !didStartLoad
    didStartLoad = true
    if isFirstLoad {
      try? await Task.sleep(nanoseconds: UInt64(loadDelay * 1_000_000_000))
    }
    didFinishLoad = true
    return PurchaseSnapshot(
      purchases: [],
      customerInfo: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    )
  }

  func isEligibleForIntroOffer(_ storeProduct: StoreProduct) async -> Bool {
    return true
  }
}
