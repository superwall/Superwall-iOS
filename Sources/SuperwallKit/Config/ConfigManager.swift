//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/06/2022.
//
// swiftlint:disable type_body_length

import UIKit
import Combine

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

  /// A dictionary of triggers by their event name.
  @DispatchQueueBacked
  var triggersByEventName: [String: Trigger] = [:]

  /// A memory store of assignments that are yet to be confirmed.
  ///
  /// When the trigger is fired, the assignment is confirmed and stored to disk.
  @DispatchQueueBacked
  var unconfirmedAssignments: [Experiment.ID: Experiment.Variant] = [:]

  var configRetryCount = 0

  private unowned let storeKitManager: StoreKitManager
  private unowned let storage: Storage
  private unowned let network: Network
  private unowned let paywallManager: PaywallManager
  private unowned let deviceHelper: DeviceHelper

  /// A task that is non-`nil` when preloading all paywalls.
  private var currentPreloadingTask: Task<Void, Never>?

  typealias Factory = RequestFactory
    & RuleAttributesFactory
    & ReceiptFactory
    & DeviceHelperFactory
  private let factory: Factory

  init(
    options: SuperwallOptions,
    storeKitManager: StoreKitManager,
    storage: Storage,
    network: Network,
    paywallManager: PaywallManager,
    deviceHelper: DeviceHelper,
    factory: Factory
  ) {
    self.options = options
    self.storeKitManager = storeKitManager
    self.storage = storage
    self.network = network
    self.paywallManager = paywallManager
    self.deviceHelper = deviceHelper
    self.factory = factory
  }

  /// This refreshes config, requiring paywalls to reload and removing unused paywall view controllers.
  /// It fails quietly, falling back to the old config.
  func refreshConfiguration() async {
    // Make sure config already exists
    guard let oldConfig = config else {
      return
    }

    // Ensure the config refresh feature flag is enabled
    guard oldConfig.featureFlags.enableConfigRefresh == true else {
      return
    }

    do {
      let newConfig = try await network.getConfig()

      // Remove all paywalls and paywall vcs that have either been removed or changed.
      let removedOrChangedPaywallIds = await getRemovedOrChangedPaywallIds(oldConfig: oldConfig, newConfig: newConfig)
      await paywallManager.removePaywalls(withIds: removedOrChangedPaywallIds)

      await processConfig(newConfig, isFirstTime: false)
      configState.send(.retrieved(newConfig))
      await Superwall.shared.track(InternalSuperwallEvent.ConfigRefresh())
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

  /// Gets the paywall IDs that no longer exist in the newly retrieved config, minus
  /// any presenting paywall.
  private func getRemovedOrChangedPaywallIds(
    oldConfig: Config,
    newConfig: Config
  ) async -> Set<String> {
    let oldPaywalls = oldConfig.paywalls
    let newPaywalls = newConfig.paywalls

    let oldPaywallIds = Set(oldPaywalls.map { $0.identifier })
    let newPaywallIds = Set(newPaywalls.map { $0.identifier })

    // Create dictionary for quick lookup of cacheKeys
    let oldPaywallCacheKeys = Dictionary(uniqueKeysWithValues: oldPaywalls.map { ($0.identifier, $0.cacheKey) })

    let removedPaywallIds = oldPaywallIds.subtracting(newPaywallIds)

    // Find identifiers that are no longer in the new configuration or whose cacheKey has changed
    let removedOrChangedPaywallIds = removedPaywallIds
      .union(
        newPaywalls.filter { paywall in
          let cacheKeyExists = oldPaywallCacheKeys[paywall.identifier] != nil
          let cacheKeyChanged = oldPaywallCacheKeys[paywall.identifier] != paywall.cacheKey
          return cacheKeyExists && cacheKeyChanged
        }.map { $0.identifier }
      )

    return removedOrChangedPaywallIds
  }

  func fetchConfiguration() async {
    do {
      _ = await factory.loadPurchasedProducts()

      async let configRequest = network.getConfig { [weak self] attempt in
        self?.configRetryCount = attempt
        self?.configState.send(.retrying)
      }
      async let geoRequest: Void = deviceHelper.getGeoInfo()

      let (config, _) = try await (configRequest, geoRequest)

      let deviceAttributes = await factory.makeSessionDeviceAttributes()
      await Superwall.shared.track(
        InternalSuperwallEvent.DeviceAttributes(deviceAttributes: deviceAttributes)
      )

      await processConfig(config, isFirstTime: true)

      configState.send(.retrieved(config))

      Task { await preloadPaywalls() }
    } catch {
      configState.send(completion: .failure(error))
      Logger.debug(
        logLevel: .error,
        scope: .superwallCore,
        message: "Failed to Fetch Configuration",
        info: nil,
        error: error
      )
    }
  }

  private func processConfig(
    _ config: Config,
    isFirstTime: Bool
  ) async {
    storage.save(config.featureFlags.disableVerboseEvents, forType: DisableVerboseEvents.self)
    triggersByEventName = ConfigLogic.getTriggersByEventName(from: config.triggers)
    choosePaywallVariants(from: config.triggers)
    if isFirstTime {
      await checkForTouchesBeganTrigger(in: config.triggers)
    }
  }

  /// Reassigns variants and preloads paywalls again.
  func reset() {
    guard let config = configState.value.getConfig() else {
      return
    }
    unconfirmedAssignments.removeAll()
    choosePaywallVariants(from: config.triggers)
    Task { await preloadPaywalls() }
  }

  /// Swizzles the UIWindow's `sendEvent` to intercept the first `began` touch event if
  /// config's triggers contain `touches_began`.
  private func checkForTouchesBeganTrigger(in triggers: Set<Trigger>) async {
    if triggers.contains(where: { $0.eventName == SuperwallEvent.touchesBegan.description }) {
      await UIWindow.swizzleSendEvent()
    }
  }

  // MARK: - Assignments

  private func choosePaywallVariants(from triggers: Set<Trigger>) {
    updateAssignments { confirmedAssignments in
      ConfigLogic.chooseAssignments(
        fromTriggers: triggers,
        confirmedAssignments: confirmedAssignments
      )
    }
  }

  /// Gets the assignments from the server and saves them to disk, overwriting any that already exist on disk/in memory.
  func getAssignments() async throws {
    let config = try await configState
      .compactMap { $0.getConfig() }
      .throwableAsync()

    let triggers = config.triggers

    guard !triggers.isEmpty else {
      return
    }

    do {
      let assignments = try await network.getAssignments()

      updateAssignments { confirmedAssignments in
        ConfigLogic.transferAssignmentsFromServerToDisk(
          assignments: assignments,
          triggers: triggers,
          confirmedAssignments: confirmedAssignments,
          unconfirmedAssignments: unconfirmedAssignments
        )
      }

      if Superwall.shared.options.paywalls.shouldPreload {
        Task { await preloadAllPaywalls() }
      }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .configManager,
        message: "Error retrieving assignments.",
        error: error
      )
    }
  }

  /// Sends an assignment confirmation to the server and updates on-device assignments.
  func confirmAssignment(_ assignment: ConfirmableAssignment) {
    let postback: AssignmentPostback = .create(from: assignment)
    Task { await network.confirmAssignments(postback) }

    updateAssignments { confirmedAssignments in
      ConfigLogic.move(
        assignment,
        from: unconfirmedAssignments,
        to: confirmedAssignments
      )
    }
  }

  /// Performs a given operation on the confirmed assignments, before updating both confirmed
  /// and unconfirmed assignments.
  ///
  /// - Parameters:
  ///   - operation: Provided logic that takes confirmed assignments by ID and returns updated assignments.
  private func updateAssignments(
    using operation: ([Experiment.ID: Experiment.Variant]) -> ConfigLogic.AssignmentOutcome
  ) {
    var confirmedAssignments = storage.getConfirmedAssignments()

    let updatedAssignments = operation(confirmedAssignments)
    unconfirmedAssignments = updatedAssignments.unconfirmed
    confirmedAssignments = updatedAssignments.confirmed

    storage.saveConfirmedAssignments(confirmedAssignments)
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
    let confirmedAssignments = storage.getConfirmedAssignments()
    return ConfigLogic.getActiveTreatmentPaywallIds(
      forTriggers: preloadableTriggers,
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
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
    guard currentPreloadingTask == nil else {
      return
    }
    currentPreloadingTask = Task {
      guard let config = try? await configState
        .compactMap({ $0.getConfig() })
        .throwableAsync() else {
        return
      }
      let expressionEvaluator = ExpressionEvaluator(
        storage: storage,
        factory: factory
      )
      let triggers = ConfigLogic.filterTriggers(
        config.triggers,
        removing: config.preloadingDisabled
      )
      let confirmedAssignments = storage.getConfirmedAssignments()
      var paywallIds = await ConfigLogic.getAllActiveTreatmentPaywallIds(
        fromTriggers: triggers,
        confirmedAssignments: confirmedAssignments,
        unconfirmedAssignments: unconfirmedAssignments,
        expressionEvaluator: expressionEvaluator
      )
      // Do not preload the presented paywall. This is because if config refreshes, we
      // don't want to refresh the presented paywall until it's dismissed and presented again.
      if let presentedPaywallId = await paywallManager.presentedViewController?.paywall.identifier {
        paywallIds.remove(presentedPaywallId)
      }
      await preloadPaywalls(withIdentifiers: paywallIds)

      currentPreloadingTask = nil
    }
  }

  /// Preloads paywalls referenced by the provided triggers.
  func preloadPaywalls(for eventNames: Set<String>) async {
    guard let config = try? await configState
      .compactMap({ $0.getConfig() })
      .throwableAsync() else {
        return
      }
    let triggersToPreload = config.triggers.filter { eventNames.contains($0.eventName) }
    let triggerPaywallIdentifiers = getTreatmentPaywallIds(from: triggersToPreload)
    await preloadPaywalls(
      withIdentifiers: triggerPaywallIdentifiers
    )
  }

  /// Preloads paywalls referenced by triggers.
  private func preloadPaywalls(withIdentifiers paywallIdentifiers: Set<String>) async {
    await withTaskGroup(of: Void.self) { group in
      for identifier in paywallIdentifiers {
        group.addTask { [weak self] in
          guard let self = self else {
            return
          }
          let request = self.factory.makePaywallRequest(
            eventData: nil,
            responseIdentifiers: .init(paywallId: identifier),
            overrides: nil,
            isDebuggerLaunched: false,
            presentationSourceType: nil,
            retryCount: 6
          )
          guard let paywall = try? await paywallManager.getPaywall(from: request) else {
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
  }
}
