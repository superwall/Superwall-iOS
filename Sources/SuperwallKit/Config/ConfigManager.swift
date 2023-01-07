//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/06/2022.
//

import UIKit

class ConfigManager {
  /// The configuration of the Superwall dashboard
  @Published var config: Config?

  /// Options for configuring the SDK.
  @Published var options = SuperwallOptions()

  /// A dictionary of triggers by their event name.
  var triggersByEventName: [String: Trigger] = [:]

  /// A memory store of assignments that are yet to be confirmed.
  ///
  /// When the trigger is fired, the assignment is confirmed and stored to disk.
  var unconfirmedAssignments: [Experiment.ID: Experiment.Variant] = [:]

  private unowned let storeKitManager: StoreKitManager
  private unowned let storage: Storage
  private unowned let network: Network
  private unowned let paywallManager: PaywallManager
  private unowned var deviceHelper: DeviceHelper!
  private let factory: RequestFactory

  /// **NOTE**: Remember to call `postInit`after init.
  init(
    storeKitManager: StoreKitManager,
    storage: Storage,
    network: Network,
    paywallManager: PaywallManager,
    factory: RequestFactory
  ) {
    self.storeKitManager = storeKitManager
    self.storage = storage
    self.network = network
    self.paywallManager = paywallManager
    self.factory = factory
  }

  func postInit(deviceHelper: DeviceHelper) {
    self.deviceHelper = deviceHelper
  }

  func fetchConfiguration(requestId: String = UUID().uuidString) async {
    do {
      let config = try await network.getConfig(withRequestId: requestId)
      Task { await sendProductsBack(from: config) }

      triggersByEventName = ConfigLogic.getTriggersByEventName(from: config.triggers)
      choosePaywallVariants(from: config.triggers)
      self.config = config
      await storeKitManager.loadPurchasedProducts()
      Task { await preloadPaywalls() }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .superwallCore,
        message: "Failed to Fetch Configuration",
        info: nil,
        error: error
      )
    }
  }

  /// Reassigns variants and preloads paywalls again.
  func reset() {
    guard let config = config else {
      return
    }
    unconfirmedAssignments.removeAll()
    choosePaywallVariants(from: config.triggers)
    Task { await preloadPaywalls() }
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
  func getAssignments() async {
    guard
      let triggers = config?.triggers,
      !triggers.isEmpty
    else {
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

      if Superwall.options.paywalls.shouldPreload {
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

  /// Gets the paywall response from the static config, if the device locale starts with "en" and no more specific version can be found.
  func getStaticPaywall(withId paywallId: String?) -> Paywall? {
    return ConfigLogic.getStaticPaywall(
      withId: paywallId,
      config: config,
      deviceLocale: deviceHelper.locale
    )
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
    guard let config = config else {
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
    guard Superwall.options.paywalls.shouldPreload else {
      return
    }
    await preloadAllPaywalls()
  }

  /// Preloads paywalls referenced by triggers.
  func preloadAllPaywalls() async {
    let config = await $config.hasValue()
    let triggers = ConfigLogic.filterTriggers(
      config.triggers,
      removing: config.preloadingDisabled
    )
    let confirmedAssignments = storage.getConfirmedAssignments()
    let paywallIds = ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
    )
    preloadPaywalls(withIdentifiers: paywallIds)
  }

  /// Preloads paywalls referenced by the provided triggers.
  func preloadPaywalls(for eventNames: Set<String>) async {
    let config = await $config.hasValue()
    let triggersToPreload = config.triggers.filter { eventNames.contains($0.eventName) }
    let triggerPaywallIdentifiers = getTreatmentPaywallIds(from: triggersToPreload)
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by triggers.
  private func preloadPaywalls(withIdentifiers paywallIdentifiers: Set<String>) {
    for identifier in paywallIdentifiers {
      Task {
        let request = factory.makePaywallRequest(withId: identifier)
        _ = try? await paywallManager.getPaywallViewController(
          from: request,
          cached: true
        )
      }
    }
  }

  /// This sends product data back to the dashboard.
  private func sendProductsBack(from config: Config) async {
    guard config.featureFlags.enablePostback else {
      return
    }
    let oneSecond = UInt64(1_000_000_000)
    let nanosecondDelay = UInt64(config.postback.postbackDelay) * oneSecond

    do {
      try await Task.sleep(nanoseconds: nanosecondDelay)

      let productIds = config.postback.productsToPostBack.map { $0.identifier }
      let products = try await storeKitManager.getProducts(withIds: productIds)
      let postbackProducts = products.productsById.values.map(PostbackProduct.init)
      let postback = Postback(products: postbackProducts)
      await network.sendPostback(postback)
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .debugViewController,
        message: "No Paywall Response",
        info: nil,
        error: error
      )
    }
  }
}