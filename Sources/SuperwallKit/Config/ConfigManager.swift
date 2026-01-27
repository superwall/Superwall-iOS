//
//  File.swift
//
//
//  Created by Yusuf Tör on 22/06/2022.
//
// swiftlint:disable type_body_length file_length

import Combine
import UIKit

class ConfigManager {
  /// A publisher that emits just once only when `config` is non-`nil`.
  var hasConfig: AnyPublisher<Config, Error> {
    configState
      .compactMap { $0.getConfig() }
      .first()
      .eraseToAnyPublisher()
  }

  /// The configuration of the Superwall dashboard
  var configState = CurrentValueSubject<ConfigState, Error>(.retrieving)

  /// Convenience variable to access config.
  var config: Config? {
    return configState.value.getConfig()
  }

  /// Options for configuring the SDK.
  var options: SuperwallOptions

  /// A dictionary of triggers by their placement name.
  @DispatchQueueBacked
  var triggersByPlacementName: [String: Trigger] = [:]

  var configRetryCount = 0

  private unowned let storeKitManager: StoreKitManager
  unowned let storage: Storage
  private unowned let network: Network
  private unowned let paywallManager: PaywallManager
  private unowned let deviceHelper: DeviceHelper
  private unowned let entitlementsInfo: EntitlementsInfo
  private unowned let webEntitlementRedeemer: WebEntitlementRedeemer
  let expressionEvaluator: CELEvaluator

  /// A task that is non-`nil` when preloading all paywalls.
  private var currentPreloadingTask: Task<Void, Never>?

  typealias Factory = RequestFactory
    & AudienceFilterAttributesFactory
    & ReceiptFactory
    & DeviceHelperFactory
    & TestModeManagerFactory
    & HasExternalPurchaseControllerFactory
  private let factory: Factory

  init(
    options: SuperwallOptions,
    storeKitManager: StoreKitManager,
    storage: Storage,
    network: Network,
    paywallManager: PaywallManager,
    deviceHelper: DeviceHelper,
    entitlementsInfo: EntitlementsInfo,
    webEntitlementRedeemer: WebEntitlementRedeemer,
    factory: Factory
  ) {
    self.options = options
    self.storeKitManager = storeKitManager
    self.storage = storage
    self.network = network
    self.paywallManager = paywallManager
    self.deviceHelper = deviceHelper
    self.entitlementsInfo = entitlementsInfo
    self.webEntitlementRedeemer = webEntitlementRedeemer
    self.factory = factory
    self.expressionEvaluator = CELEvaluator(
      storage: self.storage,
      factory: self.factory
    )
  }

  /// This refreshes config, requiring paywalls to reload and removing unused paywall view controllers.
  /// It fails quietly, falling back to the old config.
  ///
  /// - Parameters:
  ///   - oldConfig: If provided, uses this config. Otherwise uses stored config.
  ///   - isUserInitiated: If `true`, bypasses the feature flag check. Defaults to `false`.
  func refreshConfiguration(
    oldConfig: Config? = nil,
    isUserInitiated: Bool = false
  ) async {
    let wasConfigProvided = oldConfig != nil

    // If oldConfig is provided, use it. Otherwise, make sure config already exists.
    guard let oldConfig = oldConfig ?? config else {
      return
    }

    // Ensure the config refresh feature flag is enabled (skip check if oldConfig was provided or user-initiated)
    let shouldBypassFeatureFlagCheck = wasConfigProvided || isUserInitiated
    guard shouldBypassFeatureFlagCheck || oldConfig.featureFlags.enableConfigRefresh == true else {
      return
    }

    do {
      Task {
        try? await deviceHelper.getEnrichment()
      }
      let startAt = Date()
      let newConfig = try await network.getConfig { [weak self] attempt in
        self?.configRetryCount = attempt
      }
      let fetchDuration = Date().timeIntervalSince(startAt)

      // Remove all paywalls and paywall vcs that have either been removed or changed.
      let removedOrChangedPaywallIds = ConfigLogic.getRemovedOrChangedPaywallIds(
        oldConfig: oldConfig,
        newConfig: newConfig
      )
      await paywallManager.removePaywalls(withIds: removedOrChangedPaywallIds)

      await processConfig(newConfig, isFirstTime: false)
      configState.send(.retrieved(newConfig))

      let configRefresh = InternalSuperwallEvent.ConfigRefresh(
        buildId: newConfig.buildId,
        retryCount: configRetryCount,
        cacheStatus: .notCached,
        fetchDuration: fetchDuration
      )
      await Superwall.shared.track(configRefresh)
      Task { await preloadPaywalls() }
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Failed to refresh configuration.",
        info: nil,
        error: error
      )
    }
  }

  func fetchConfiguration() async {
    do {
      let startAt = Date()

      // Step 1: Determine fetch strategy based on subscription status and cached data
      let cachedConfig = storage.get(LatestConfig.self)
      let cachedSubsStatus = storage.get(SubscriptionStatusKey.self)

      let isSubscribed: Bool
      if case .active = cachedSubsStatus {
        isSubscribed = true
      } else {
        isSubscribed = false
      }

      let shouldFetchAsync = cachedConfig != nil && isSubscribed

      // Step 2: Fetch or use cached config
      let fetchResult = try await fetchConfig(
        cachedConfig: cachedConfig,
        shouldFetchAsync: shouldFetchAsync,
        startAt: startAt
      )
      let config = fetchResult.config
      let isUsingCachedConfig = fetchResult.isUsingCached
      let configFetchDuration = fetchResult.fetchDuration

      // Step 3: Handle enrichment (use cached if async, fetch with timeout if sync)
      let usingCachedEnrichment = await handleEnrichment(
        shouldFetchAsync: shouldFetchAsync,
        cachedConfig: cachedConfig
      )

      // Step 4: Track config fetch event (only for sync path)
      if !shouldFetchAsync {
        trackConfigFetch(
          config: config,
          isUsingCachedConfig: isUsingCachedConfig,
          configFetchDuration: configFetchDuration
        )
      }

      // Step 5: Track device attributes
      let deviceAttributes = await factory.makeSessionDeviceAttributes()
      await Superwall.shared.track(
        InternalSuperwallEvent.DeviceAttributes(deviceAttributes: deviceAttributes)
      )

      // Step 6: Process config and set state
      await processConfig(config, isFirstTime: true)
      configState.send(.retrieved(config))

      // Step 7: Schedule background tasks
      scheduleBackgroundTasks(
        shouldFetchAsync: shouldFetchAsync,
        isUsingCachedConfig: isUsingCachedConfig,
        usingCachedEnrichment: usingCachedEnrichment,
        config: config
      )
    } catch {
      handleConfigFetchError(error)
    }
  }

  // MARK: - Config Fetch Helpers

  private struct ConfigFetchResult {
    let config: Config
    let isUsingCached: Bool
    let fetchDuration: TimeInterval
  }

  private func fetchConfig(
    cachedConfig: Config?,
    shouldFetchAsync: Bool,
    startAt: Date
  ) async throws -> ConfigFetchResult {
    if shouldFetchAsync {
      // Use cached config immediately for subscribed users
      guard let cachedConfig = cachedConfig else {
        throw NSError(
          domain: "ConfigManager",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Cached config unexpectedly nil"]
        )
      }
      return ConfigFetchResult(
        config: cachedConfig,
        isUsingCached: true,
        fetchDuration: 0
      )
    } else {
      // Fetch config synchronously
      let enableConfigRefresh = cachedConfig?.featureFlags.enableConfigRefresh ?? false

      let isActive: Bool
      if case .active = storage.get(SubscriptionStatusKey.self) {
        isActive = true
      } else {
        isActive = false
      }
      let timeout: TimeInterval = isActive ? 0.5 : 1

      if let cachedConfig = cachedConfig,
        enableConfigRefresh {
        do {
          let result = try await network.getConfig(maxRetry: 0, timeout: timeout)
          return ConfigFetchResult(
            config: result,
            isUsingCached: false,
            fetchDuration: Date().timeIntervalSince(startAt)
          )
        } catch {
          return ConfigFetchResult(
            config: cachedConfig,
            isUsingCached: true,
            fetchDuration: Date().timeIntervalSince(startAt)
          )
        }
      } else {
        let config = try await network.getConfig { [weak self] attempt in
          self?.configRetryCount = attempt
          self?.configState.send(.retrying)
        }
        return ConfigFetchResult(
          config: config,
          isUsingCached: false,
          fetchDuration: Date().timeIntervalSince(startAt)
        )
      }
    }
  }

  private func handleEnrichment(
    shouldFetchAsync: Bool,
    cachedConfig: Config?
  ) async -> Bool {
    if shouldFetchAsync {
      // Use cached enrichment for async path - refreshConfiguration will fetch fresh
      if let cachedEnrichment = storage.get(LatestEnrichment.self) {
        deviceHelper.enrichment = cachedEnrichment
        return true
      }
      return false
    } else {
      // Fetch enrichment with timeout for sync path
      let enableConfigRefresh = cachedConfig?.featureFlags.enableConfigRefresh ?? false

      let isActive: Bool
      if case .active = storage.get(SubscriptionStatusKey.self) {
        isActive = true
      } else {
        isActive = false
      }
      let timeout: TimeInterval = isActive ? 0.5 : 1

      let cachedEnrichment = storage.get(LatestEnrichment.self)

      guard
        let cachedEnrichment = cachedEnrichment,
        enableConfigRefresh
      else {
        try? await deviceHelper.getEnrichment(maxRetry: 0, timeout: timeout)
        return false
      }

      do {
        try await deviceHelper.getEnrichment(maxRetry: 0, timeout: timeout)
        return false
      } catch {
        deviceHelper.enrichment = cachedEnrichment
        return true
      }
    }
  }

  private func trackConfigFetch(
    config: Config,
    isUsingCachedConfig: Bool,
    configFetchDuration: TimeInterval
  ) {
    Task {
      let cacheStatus: InternalSuperwallEvent.ConfigCacheStatus =
        isUsingCachedConfig ? .cached : .notCached
      let configRefresh = InternalSuperwallEvent.ConfigRefresh(
        buildId: config.buildId,
        retryCount: configRetryCount,
        cacheStatus: cacheStatus,
        fetchDuration: configFetchDuration
      )
      await Superwall.shared.track(configRefresh)
    }
  }

  private func scheduleBackgroundTasks(
    shouldFetchAsync: Bool,
    isUsingCachedConfig: Bool,
    usingCachedEnrichment: Bool,
    config: Config
  ) {
    Task {
      await preloadPaywalls()
    }

    if shouldFetchAsync {
      // Async path: refresh config in background (also fetches enrichment)
      Task {
        await refreshConfiguration(oldConfig: config)
      }
    } else {
      // Sync path: fetch enrichment if needed, refresh config if using cached
      if usingCachedEnrichment {
        Task {
          try? await deviceHelper.getEnrichment()
        }
      }
      if isUsingCachedConfig {
        Task {
          await refreshConfiguration()
        }
      }
    }
  }

  private func handleConfigFetchError(_ error: Error) {
    configState.send(completion: .failure(error))

    Task {
      let configFallback = InternalSuperwallEvent.ConfigFail(
        message: error.localizedDescription
      )
      await Superwall.shared.track(configFallback)
    }

    Logger.debug(
      logLevel: .error,
      scope: .superwallCore,
      message: "Failed to Fetch Configuration",
      info: nil,
      error: error
    )
  }

  private func processConfig(
    _ config: Config,
    isFirstTime: Bool
  ) async {
    storage.save(
      config.featureFlags.disableVerbosePlacements, forType: DisableVerbosePlacements.self)
    storage.save(config, forType: LatestConfig.self)
    triggersByPlacementName = ConfigLogic.getTriggersByPlacementName(from: config.triggers)
    choosePaywallVariants(from: config.triggers)

    // Evaluate test mode before loading products
    let testModeManager = factory.makeTestModeManager()
    testModeManager.evaluateTestMode(config: config)

    if testModeManager.isTestMode {
      // In test mode, fetch products from API instead of StoreKit
      await fetchTestModeProducts(testModeManager: testModeManager)
    } else {
      await factory.loadPurchasedProducts(config: config)
    }

    Task {
      await webEntitlementRedeemer.pollWebEntitlements(config: config, isFirstTime: isFirstTime)
    }
    if isFirstTime {
      await checkForTouchesBeganTrigger(in: config.triggers)

      if testModeManager.isTestMode, let reason = testModeManager.testModeReason {
        await presentTestModeColdLaunchAlert(reason: reason)
      }
    }
  }

  /// Reassigns variants and preloads paywalls again.
  func reset() async {
    do {
      let config = try await self.configState
        .compactMap { $0.getConfig() }
        .throwableAsync()

      choosePaywallVariants(from: config.triggers)

      await webEntitlementRedeemer.redeem(.existingCodes)
      await preloadPaywalls()
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .superwallCore,
        message: "There was an error awaiting config. Couldn't reset paywall variants.",
        error: error
      )
    }
  }

  /// Swizzles the UIWindow's `sendEvent` to intercept the first `began` touch event if
  /// config's triggers contain `touches_began`.
  private func checkForTouchesBeganTrigger(in triggers: Set<Trigger>) async {
    if triggers.contains(where: { $0.placementName == SuperwallEvent.touchesBegan.description }) {
      await UIWindow.swizzleSendEvent()
    }
  }

  // MARK: - Assignments

  private func choosePaywallVariants(from triggers: Set<Trigger>) {
    var assignments = storage.getAssignments()

    assignments = ConfigLogic.chooseAssignments(
      fromTriggers: triggers,
      assignments: assignments
    )

    storage.overwriteAssignments(assignments)
  }

  /// Gets the assignments from the server and saves them to disk, overwriting any that already exist on disk/in memory.
  func getAssignments() async throws {
    let config =
      try await configState
      .compactMap { $0.getConfig() }
      .throwableAsync()

    let triggers = config.triggers

    guard !triggers.isEmpty else {
      return
    }

    do {
      let serverAssignments = try await network.getAssignments()
      var localAssignments = storage.getAssignments()

      localAssignments = ConfigLogic.transferAssignments(
        fromServer: serverAssignments,
        toDisk: localAssignments,
        triggers: triggers
      )

      storage.overwriteAssignments(localAssignments)

      Task { await preloadPaywalls() }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .configManager,
        message: "Error retrieving assignments.",
        error: error
      )
    }
  }

  /// Posts back an assignment to the server and updates on-device confirmed assignments.
  func postbackAssignment(_ assignment: Assignment) {
    Task { [weak self] in
      guard let self = self else {
        return
      }
      let confirmedAssignment = await self.network.confirmAssignment(assignment)
      self.storage.updateAssignment(confirmedAssignment)
    }
  }

  // MARK: - Preloading Paywalls
  private func getTreatmentPaywallIds(from triggers: Set<Trigger>) -> Set<String> {
    guard let config = configState.value.getConfig() else {
      return []
    }
    let preloadableTriggers = ConfigLogic.filterTriggers(
      triggers,
      removing: config.preloadingDisabled
    )
    if preloadableTriggers.isEmpty {
      return []
    }
    let assignments = storage.getAssignments()
    return ConfigLogic.getActiveTreatmentPaywallIds(
      forTriggers: preloadableTriggers,
      assignments: assignments
    )
  }

  /// Preloads paywalls.
  ///
  /// A developer can disable preloading of paywalls by setting ``SuperwallOptions/shouldPreloadPaywalls``.
  private func preloadPaywalls() async {
    guard Superwall.shared.options.paywalls.shouldPreload else {
      return
    }
    await preloadAllPaywalls()
  }

  /// Preloads paywalls referenced by triggers.
  func preloadAllPaywalls() async {
    currentPreloadingTask = Task { [weak self, currentPreloadingTask] in
      guard let self = self else {
        return
      }
      // Wait until the previous task is finished before continuing.
      await currentPreloadingTask?.value

      guard
        let config = try? await self.configState
          .compactMap({ $0.getConfig() })
          .throwableAsync()
      else {
        return
      }
      let triggers = ConfigLogic.filterTriggers(
        config.triggers,
        removing: config.preloadingDisabled
      )
      let assignments = self.storage.getAssignments()
      var paywallIds = await ConfigLogic.getAllActiveTreatmentPaywallIds(
        fromTriggers: triggers,
        assignments: assignments,
        expressionEvaluator: expressionEvaluator
      )
      // Do not preload the presented paywall. This is because if config refreshes, we
      // don't want to refresh the presented paywall until it's dismissed and presented again.
      if let presentedPaywallId = await self.paywallManager.presentedViewController?.paywall.identifier {
        paywallIds.remove(presentedPaywallId)
      }

      await self.preloadPaywalls(withIdentifiers: paywallIds)
    }
  }

  /// Preloads paywalls referenced by the provided triggers.
  func preloadPaywalls(for placementNames: Set<String>) async {
    guard
      let config =
        try? await configState
        .compactMap({ $0.getConfig() })
        .throwableAsync()
    else {
      return
    }
    let triggersToPreload = config.triggers.filter { placementNames.contains($0.placementName) }
    let triggerPaywallIdentifiers = getTreatmentPaywallIds(from: triggersToPreload)
    await preloadPaywalls(
      withIdentifiers: triggerPaywallIdentifiers
    )
  }

  /// Preloads paywalls referenced by triggers.
  private func preloadPaywalls(withIdentifiers paywallIdentifiers: Set<String>) async {
    let paywallCount = paywallIdentifiers.count
    let preloadStart = InternalSuperwallEvent.PaywallPreload(
      state: .start,
      paywallCount: paywallCount
    )
    await Superwall.shared.track(preloadStart)

    await withTaskGroup(of: Void.self) { group in
      for identifier in paywallIdentifiers {
        group.addTask { [weak self] in
          guard let self = self else {
            return
          }
          let request = self.factory.makePaywallRequest(
            placementData: nil,
            responseIdentifiers: .init(paywallId: identifier),
            overrides: nil,
            isDebuggerLaunched: false,
            presentationSourceType: nil
          )
          guard let paywall = try? await self.paywallManager.getPaywall(from: request) else {
            return
          }

          await self.paywallManager.attemptToPreloadArchive(from: paywall)

          _ = try? await self.paywallManager.getViewController(
            for: paywall,
            isDebuggerLaunched: request.isDebuggerLaunched,
            isForPresentation: true,
            isPreloading: true,
            delegate: nil
          )
        }
      }
    }

    let preloadComplete = InternalSuperwallEvent.PaywallPreload(
      state: .complete,
      paywallCount: paywallCount
    )
    await Superwall.shared.track(preloadComplete)
  }

  // MARK: - Test Mode

  private func fetchTestModeProducts(testModeManager: TestModeManager) async {
    do {
      let response = try await network.getSuperwallProducts()
      testModeManager.setProducts(response.data)

      // Also populate storeKitManager.productsById with test products
      for superwallProduct in response.data {
        let testProduct = TestStoreProduct(
          superwallProduct: superwallProduct,
          entitlements: []
        )
        let storeProduct = StoreProduct(product: testProduct)
        storeKitManager.productsById[superwallProduct.identifier] = storeProduct
      }

      Logger.debug(
        logLevel: .info,
        scope: .superwallCore,
        message: "Test mode: loaded \(response.data.count) products from API"
      )
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .superwallCore,
        message: "Test mode: failed to fetch products",
        error: error
      )
    }
  }

  @MainActor
  private func presentTestModeColdLaunchAlert(reason: TestModeReason) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController else {
      return
    }

    let userId = factory.makeTestModeManager().identityManager.userId
    let hasPurchaseController = factory.makeHasExternalPurchaseController()

    TestModeColdLaunchAlert.present(
      reason: reason,
      userId: userId,
      hasPurchaseController: hasPurchaseController,
      from: rootVC
    )
  }
}
