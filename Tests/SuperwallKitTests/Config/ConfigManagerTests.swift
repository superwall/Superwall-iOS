//
//  File.swift
//
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

@testable import SuperwallKit
import Testing

struct ConfigManagerTests {
  @Test
  @available(iOS 14.0, *)
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
  @available(iOS 14.0, *)
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

  // MARK: - Confirm Assignments
  @Test
  @available(iOS 16.0, *)
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

    try? await Task.sleep(for: .seconds(1))

    #expect(network.assignmentsConfirmed)
    #expect(storage.getAssignments().first(where: { $0.experimentId == experimentId })?.variant == variant)
  }

  @Test
  @available(iOS 16.0, *)
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

    try? await Task.sleep(for: .seconds(1))

    #expect(network.assignmentsConfirmed)
    #expect(storage.getAssignments().first(where: { $0.experimentId == experimentId })?.variant == variant)
  }

  // MARK: - Load Assignments

  @Test
  @available(iOS 16.0, *)
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

    try? await Task.sleep(for: .seconds(0.1))
    task.cancel()

    #expect(storage.getAssignments().isEmpty)
  }

  @Test
  @available(iOS 14.0, *)
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
  @available(iOS 14.0, *)
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
  @available(iOS 16.0, *)
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
    try await Task.sleep(for: .seconds(0.3))
  }

  @Test
  @available(iOS 16.0, *)
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
    try? await Task.sleep(for: .seconds(0.2))
  }

  @Test
  @available(iOS 16.0, *)
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
    try? await Task.sleep(for: .seconds(0.2))
  }

  @Test
  @available(iOS 16.0, *)
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
    try? await Task.sleep(for: .seconds(0.2))
  }

  @Test
  @available(iOS 16.0, *)
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
    try? await Task.sleep(for: .seconds(0.2))
  }

  @Test
  @available(iOS 16.0, *)
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
    try? await Task.sleep(for: .seconds(0.2))
  }
}
