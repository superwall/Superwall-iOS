//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/06/2022.
//

import UIKit

class ConfigManager {
  static let shared = ConfigManager()

  var options = PaywallOptions()
  var config: Config?
  /// Used to store the config request if it occurred in the background.
  var configRequest: ConfigRequest?
  var configRequestId = ""
  var triggers: [String: Trigger] = [:]
  private let storage: Storage
  private let network: Network
  private let paywallManager: PaywallManager
  /// A memory store of assignments that are yet to be confirmed.
  ///
  /// When the trigger is fired, the assignment is confirmed and stored to disk.
  var unconfirmedAssignments: [Experiment.ID: Experiment.Variant] = [:]

  init(
    storage: Storage = .shared,
    network: Network = .shared,
    paywallManager: PaywallManager = .shared
  ) {
    self.storage = storage
    self.network = network
    self.paywallManager = paywallManager

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
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
    triggerDelayManager: TriggerDelayManager = .shared,
    appSessionManager: AppSessionManager = .shared,
    sessionEventsManager: SessionEventsManager = .shared,
    requestId: String = UUID().uuidString,
    afterReset: Bool = false
  ) {
    network.getConfig(withRequestId: requestId) { [weak self] result in
      guard let self else {
        return
      }
      switch result {
      case .success(let config):
        self.configRequestId = requestId
        appSessionManager.appSessionTimeout = config.appSessionTimeout
        self.triggers = TriggerLogic.getTriggerDictionary(from: config.triggers)
        sessionEventsManager.triggerSession.createSessions(from: config)
        self.config = config
        self.assignVariants()
        self.cacheConfig()

        if afterReset {
          triggerDelayManager.handleDelayedContent(
            storage: self.storage,
            configManager: self
          )
        } else {
          StoreKitManager.shared.loadPurchasedProducts {
            triggerDelayManager.handleDelayedContent(
              storage: self.storage,
              configManager: self
            )
          }
        }
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .paywallCore,
          message: "Failed to Fetch Configuration",
          info: nil,
          error: error
        )
      }
    }
  }

  @objc private func applicationDidBecomeActive() {
    guard let configRequest else {
      return
    }
    network.getConfig(
      withRequestId: configRequest.id,
      completion: configRequest.completion
    )
    self.configRequest = nil
  }

  // MARK: - Assignments

  private func assignVariants() {
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
  func loadAssignments(completion: (() -> Void)? = nil) {
    guard
      let triggers = config?.triggers,
      !triggers.isEmpty
    else {
      completion?()
      return
    }
    network.getAssignments { [weak self] result in
      guard let self else {
        return
      }
      switch result {
      case .success(let assignments):
        var confirmedAssignments = self.storage.getConfirmedAssignments()
        let result = ConfigLogic.transferAssignmentsFromServerToDisk(
          assignments: assignments,
          triggers: triggers,
          confirmedAssignments: confirmedAssignments,
          unconfirmedAssignments: self.unconfirmedAssignments
        )
        self.unconfirmedAssignments = result.unconfirmedAssignments
        confirmedAssignments = result.confirmedAssignments
        self.storage.saveConfirmedAssignments(confirmedAssignments)
        if Paywall.options.shouldPreloadPaywalls {
          self.preloadAllPaywalls()
        }
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .configManager,
          message: "Error retrieving assignments.",
          error: error
        )
      }
      completion?()
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

  func confirmAssignments(
    _ confirmableAssignment: ConfirmableAssignment
  ) {
    let assignmentPostback = ConfirmableAssignments(
      assignments: [
        Assignment(
          experimentId: confirmableAssignment.experimentId,
          variantId: confirmableAssignment.variant.id
        )
      ]
    )
    network.confirmAssignments(assignmentPostback)

    var confirmedAssignments = storage.getConfirmedAssignments()
    confirmedAssignments[confirmableAssignment.experimentId] = confirmableAssignment.variant
    storage.saveConfirmedAssignments(confirmedAssignments)
    unconfirmedAssignments[confirmableAssignment.experimentId] = nil
  }

  /// Preloads paywalls, products and trigger responses. It then sends the products back to the server.
  ///
  /// A developer can disable preloading of paywalls by setting ``PaywallOptions/shouldPreloadPaywalls``.
  private func cacheConfig() {
    if Paywall.options.shouldPreloadPaywalls {
      preloadAllPaywalls()
    }
    if config?.featureFlags.enablePostback == true {
      executePostback()
    }
  }

  /// Preloads paywalls referenced by triggers.
  func preloadAllPaywalls() {
    let triggerPaywallIdentifiers = getAllActiveTreatmentPaywallIds()
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  private func handlePreloadPaywallsPreConfig(
    forTriggers triggerNames: Set<String>,
    triggerDelayManager: TriggerDelayManager = .shared
  ) {
    triggerDelayManager.triggersToPreloadPreConfigCall = triggerNames
  }

  /// Preloads paywalls referenced by the provided triggers.
  func preloadPaywalls(forTriggers triggerNames: Set<String>) {
    guard let config else {
      handlePreloadPaywallsPreConfig(forTriggers: triggerNames)
      return
    }
    let triggersToPreload = config.triggers.filter { triggerNames.contains($0.eventName) }
    let triggerPaywallIdentifiers = getTreatmentPaywallIds(from: triggersToPreload)
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by triggers.
  private func preloadPaywalls(withIdentifiers paywallIdentifiers: Set<String>) {
    for identifier in paywallIdentifiers {
      paywallManager.getPaywallViewController(
        responseIdentifiers: .init(paywallId: identifier),
        cached: true
      )
    }
  }

  /// This sends product data back to the dashboard
  private func executePostback() {
    guard let config else {
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
          self?.network.sendPostback(postback)
        case .failure:
          break
        }
      }
    }
  }
}
