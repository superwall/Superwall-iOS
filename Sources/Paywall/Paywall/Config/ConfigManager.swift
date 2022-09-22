//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/06/2022.
//

import UIKit
import Combine

class ConfigManager {
  static let shared = ConfigManager()

  var options = PaywallOptions()
  @Published var config: Config?
  var configRequestId = ""
  /// Used to store the config request if it occurred in the background.
  var pendingConfigRequest: PendingConfigRequest?
  var triggers: [String: Trigger] = [:]
  private let storage: Storage
  private let network: Network
  private let paywallManager: PaywallManager
  /// A memory store of assignments that are yet to be confirmed.
  ///
  /// When the trigger is fired, the assignment is confirmed and stored to disk.
  var unconfirmedAssignments: [Experiment.ID: Experiment.Variant] = [:]
  private var cancellables: [AnyCancellable] = []

  init(
    storage: Storage = .shared,
    network: Network = .shared,
    paywallManager: PaywallManager = .shared
  ) {
    self.storage = storage
    self.network = network
    self.paywallManager = paywallManager
  }

  func setOptions(_ options: PaywallOptions?) {
    self.options = options ?? self.options
  }

  /// Called when storage is cleared on ``Paywall/Paywall/reset()``.
  /// This happens when a user logs out.
  func clear() {
    triggers.removeAll()
    unconfirmedAssignments.removeAll()
    config = nil
  }

  func fetchConfiguration(
    applicationState: UIApplication.State? = nil,
    triggerDelayManager: TriggerDelayManager = .shared,
    appSessionManager: AppSessionManager = .shared,
    sessionEventsManager: SessionEventsManager = .shared,
    requestId: String = UUID().uuidString
  ) async {
    do {
      let config = try await network.getConfig(withRequestId: requestId)

      configRequestId = requestId
      appSessionManager.appSessionTimeout = config.appSessionTimeout
      triggers = TriggerLogic.getTriggerDictionary(from: config.triggers)
      sessionEventsManager.triggerSession.createSessions(from: config)
      assignVariants(from: config.triggers)
      executePostback(from: config)
      self.config = config
      preloadPaywalls()
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallCore,
        message: "Failed to Fetch Configuration",
        info: nil,
        error: error
      )
    }
  }

  // MARK: - Assignments

  private func assignVariants(from triggers: Set<Trigger>) {
    var confirmedAssignments = storage.getConfirmedAssignments()
    guard let triggers = config?.triggers else {
      return
    }
    let result = ConfigLogic.assignVariants(
      fromTriggers: triggers,
      confirmedAssignments: confirmedAssignments
    )
    unconfirmedAssignments = result.unconfirmedAssignments
    confirmedAssignments = result.confirmedAssignments
    storage.saveConfirmedAssignments(confirmedAssignments)
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

      var confirmedAssignments = storage.getConfirmedAssignments()
      let result = ConfigLogic.transferAssignmentsFromServerToDisk(
        assignments: assignments,
        triggers: triggers,
        confirmedAssignments: confirmedAssignments,
        unconfirmedAssignments: self.unconfirmedAssignments
      )
      unconfirmedAssignments = result.unconfirmedAssignments
      confirmedAssignments = result.confirmedAssignments
      storage.saveConfirmedAssignments(confirmedAssignments)
      if Paywall.options.shouldPreloadPaywalls {
        self.preloadAllPaywalls()
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

  /// Gets the paywall response from the static config, if the device locale starts with "en" and no more specific version can be found.
  func getStaticPaywallResponse(forPaywallId paywallId: String?) -> PaywallResponse? {
    return ConfigLogic.getStaticPaywallResponse(
      fromPaywallId: paywallId,
      config: config
    )
  }

  private func getAllActiveTreatmentPaywallIds() -> Set<String> {
    guard let triggers = config?.triggers else {
      return []
    }
    let confirmedAssignments = storage.getConfirmedAssignments()
    return ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
    )
  }

  private func getTreatmentPaywallIds(from triggers: Set<Trigger>) -> Set<String> {
    let confirmedAssignments = storage.getConfirmedAssignments()
    return ConfigLogic.getActiveTreatmentPaywallIds(
      forTriggers: triggers,
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
    )
  }

  func confirmAssignments(_ confirmableAssignment: ConfirmableAssignment) {
    let assignmentPostback = ConfirmableAssignments(
      assignments: [
        Assignment(
          experimentId: confirmableAssignment.experimentId,
          variantId: confirmableAssignment.variant.id
        )
      ]
    )

    Task { await network.confirmAssignments(assignmentPostback) }

    var confirmedAssignments = storage.getConfirmedAssignments()
    confirmedAssignments[confirmableAssignment.experimentId] = confirmableAssignment.variant
    storage.saveConfirmedAssignments(confirmedAssignments)
    unconfirmedAssignments[confirmableAssignment.experimentId] = nil
  }

  /// Preloads paywalls.
  ///
  /// A developer can disable preloading of paywalls by setting ``PaywallOptions/shouldPreloadPaywalls``.
  private func preloadPaywalls() {
    guard Paywall.options.shouldPreloadPaywalls else {
      return
    }
    preloadAllPaywalls()
  }

  /// Preloads paywalls referenced by triggers.
  func preloadAllPaywalls() {
    let triggerPaywallIdentifiers = getAllActiveTreatmentPaywallIds()
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by the provided triggers.
  func preloadPaywalls(forTriggers triggerNames: Set<String>) async {
    let config = await $config.hasValue()
    let triggersToPreload =  config.triggers.filter { triggerNames.contains($0.eventName) }
    let triggerPaywallIdentifiers = getTreatmentPaywallIds(from: triggersToPreload)
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by triggers.
  private func preloadPaywalls(withIdentifiers paywallIdentifiers: Set<String>) {
    for identifier in paywallIdentifiers {
      Task {
        try? await paywallManager.getPaywallViewController(
          responseIdentifiers: .init(paywallId: identifier),
          cached: true
        )
      }
    }
  }

  /// This sends product data back to the dashboard
  private func executePostback(from config: Config) {
    guard config.featureFlags.enablePostback else {
      return
    }
    // TODO: Does this need to be on the main thread?
    DispatchQueue.main.asyncAfter(deadline: .now() + config.postback.postbackDelay) {
      let productIds = config.postback.productsToPostBack.map { $0.identifier }
      StoreKitManager.shared.getProducts(withIds: productIds) { [weak self] result in
        switch result {
        case .success(let output):
          let products = output.productsById.values.map(PostbackProduct.init)
          let postback = Postback(products: products)
          Task { await self?.network.sendPostback(postback) }
        case .failure:
          break
        }
      }
    }
  }
}
