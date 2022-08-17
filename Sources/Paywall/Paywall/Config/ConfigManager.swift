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
  /// A memory store of assignments that are yet to be confirmed.
  ///
  /// When the trigger is fired, the assignment is confirmed and stored to disk.
  var unconfirmedAssignments: [Experiment.ID: Experiment.Variant] = [:]

  init(
    storage: Storage = Storage.shared,
    network: Network = Network.shared
  ) {
    self.storage = storage
    self.network = network

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
  }

  func fetchConfiguration() {
    TriggerDelayManager.shared.enterConfigDispatchQueue()
    let requestId = UUID().uuidString
    Network.shared.getConfig(withRequestId: requestId) { [weak self] result in
      guard let self = self else {
        return
      }
      switch result {
      case .success(let config):
        self.configRequestId = requestId
        AppSessionManager.shared.appSessionTimeout = config.appSessionTimeout
        self.triggers = StorageLogic.getTriggerDictionary(from: config.triggers)

        SessionEventsManager.shared.triggerSession.createSessions(from: config)
        self.config = config
        self.assignVariants()
        self.cacheConfig()
        TriggerDelayManager.shared.leaveConfigDispatchQueue()
        TriggerDelayManager.shared.fireDelayedTriggers()
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .paywallCore,
          message: "Failed to Fetch Configuration",
          info: nil,
          error: error
        )
        TriggerDelayManager.shared.leaveConfigDispatchQueue()
        TriggerDelayManager.shared.fireDelayedTriggers()
      }
    }
  }

  @objc private func applicationDidBecomeActive() {
    guard let configRequest = configRequest else {
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
    var confirmedAssignments = Storage.shared.getConfirmedAssignments()
    guard let triggers = config?.triggers else {
      return
    }
    let result = ConfigLogic.assignVariants(
      fromTriggers: triggers,
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
    )
    unconfirmedAssignments = result.unconfirmedAssignments
    confirmedAssignments = result.confirmedAssignments
    Storage.shared.saveConfirmedAssignments(confirmedAssignments)
  }

  /// Gets the assignments from the server and saves them to disk, overwriting any that already exist on disk/in memory.
  func getAssignments(completion: (() -> Void)? = nil) {
    guard let triggers = config?.triggers else {
      completion?()
      return
    }
    Network.shared.getAssignments { [weak self] result in
      guard let self = self else {
        return
      }
      switch result {
      case .success(let assignments):
        var confirmedAssignments = Storage.shared.getConfirmedAssignments()
        let result = ConfigLogic.processAssignmentsFromServer(
          assignments,
          triggers: triggers,
          confirmedAssignments: confirmedAssignments,
          unconfirmedAssignments: self.unconfirmedAssignments
        )
        self.unconfirmedAssignments = result.unconfirmedAssignments
        confirmedAssignments = result.confirmedAssignments
        Storage.shared.saveConfirmedAssignments(confirmedAssignments)
        self.cacheConfig()
        completion?()
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .configManager,
          message: "Error retrieving assignments.",
          error: error
        )
      }
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
    // TODO: Extract confirmed assignments into memory to reduce load time.
    let confirmedAssignments = Storage.shared.getConfirmedAssignments()
    return ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
    )
  }

  private func getTreatmentPaywallIds(from triggers: Set<Trigger>) -> Set<String> {
    // TODO: Extract confirmed assignments into memory to reduce load time.
    let confirmedAssignments = Storage.shared.getConfirmedAssignments()
    return ConfigLogic.getActiveTreatmentPaywallIds(
      forTriggers: triggers,
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
    )
  }

  func confirmAssignments(
    _ confirmableAssignment: ConfirmableAssignment,
    network: Network = .shared
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

    var confirmedAssignments = Storage.shared.getConfirmedAssignments()
    confirmedAssignments[confirmableAssignment.experimentId] = confirmableAssignment.variant
    Storage.shared.saveConfirmedAssignments(confirmedAssignments)
    unconfirmedAssignments[confirmableAssignment.experimentId] = nil
  }

  /// Preloads paywalls, products, trigger paywalls, and trigger responses. It then sends the products back to the server.
  ///
  /// A developer can disable preloading of paywalls by setting ``PaywallOptions/shouldPreloadPaywalls``.
  private func cacheConfig() {
    if Paywall.options.shouldPreloadPaywalls {
      preloadAllPaywalls()
    }
    executePostback()
  }

  /// Preloads paywalls referenced by triggers.
  func preloadAllPaywalls() {
    let triggerPaywallIdentifiers = getAllActiveTreatmentPaywallIds()
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by the provided triggers.
  func preloadPaywalls(forTriggers triggerNames: Set<String>) {
    guard let config = config else {
      return
    }
    let triggersToPreload = config.triggers.filter { triggerNames.contains($0.eventName) }
    let triggerPaywallIdentifiers = getTreatmentPaywallIds(from: triggersToPreload)
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by triggers.
  private func preloadPaywalls(withIdentifiers paywallIdentifiers: Set<String>) {
    for identifier in paywallIdentifiers {
      PaywallManager.shared.getPaywallViewController(
        responseIdentifiers: .init(paywallId: identifier),
        cached: true
      )
    }
  }

  /// This sends product data back to the dashboard
  private func executePostback() {
    guard let config = config else {
      return
    }
    // TODO: Does this need to be on the main thread?
    DispatchQueue.main.asyncAfter(deadline: .now() + config.postback.postbackDelay) {
      let productIds = config.postback.productsToPostBack.map { $0.identifier }
      StoreKitManager.shared.getProducts(withIds: productIds) { result in
        switch result {
        case .success(let productsById):
          let products = productsById.values.map(PostbackProduct.init)
          let postback = Postback(products: products)
          Network.shared.sendPostback(postback)
        case .failure:
          break
        }
      }
    }
  }
}
