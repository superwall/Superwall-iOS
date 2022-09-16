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
    applicationState: UIApplication.State? = nil,
    triggerDelayManager: TriggerDelayManager = .shared,
    appSessionManager: AppSessionManager = .shared,
    sessionEventsManager: SessionEventsManager = .shared,
    requestId: String = UUID().uuidString,
    afterReset: Bool = false
  ) async {
    if await isCalledInBackground(
      applicationState,
      withRequestId: requestId,
      afterReset: afterReset
    ) {
      return
    }

    do {
      let config = try await network.getConfig(withRequestId: requestId)

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



  // TODO: MAYBE MOVE THIS SUCH THAT WE STORE A VALUE THAT ITS CALLED IN BG AND JUST RERUN THE
  // TODO: FETCH CONFIG CALL BUT PASS IN THE REQUESTID. COULD MOVE THIS TO THE CONFIG MANAGER TOO? ALTHOUGH MAYBE ITS REQUEST
  // TODO: SPECIFIC...
  @MainActor
  private func isCalledInBackground(
    _ applicationState: UIApplication.State?,
    withRequestId requestId: String,
    afterReset: Bool
  ) -> Bool {
    let applicationState = applicationState ?? UIApplication.shared.applicationState
    if applicationState == .background {
      let pendingConfigRequest = PendingConfigRequest(
        requestId: requestId,
        afterReset: afterReset
      )
      self.pendingConfigRequest = pendingConfigRequest
      return true
    }
    return false
  }

  @objc private func applicationDidBecomeActive() async {
    guard let pendingConfigRequest = pendingConfigRequest else {
      return
    }
    await fetchConfiguration(
      requestId: pendingConfigRequest.requestId,
      afterReset: pendingConfigRequest.afterReset
    )
    self.pendingConfigRequest = nil
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
  func loadAssignments() async {
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
    guard let config = config else {
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
    guard let config = config else {
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
