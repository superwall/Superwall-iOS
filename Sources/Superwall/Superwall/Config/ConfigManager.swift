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

  var options = SuperwallOptions()
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

  func setOptions(_ options: SuperwallOptions?) {
    self.options = options ?? self.options
  }

  func fetchConfiguration(
    applicationState: UIApplication.State? = nil,
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
      Task {
        await executePostback(from: config)
      }
      self.config = config
      preloadPaywalls()
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
    assignVariants(from: config.triggers)
    preloadPaywalls()
  }

  // MARK: - Assignments

  private func assignVariants(from triggers: Set<Trigger>) {
    var confirmedAssignments = storage.getConfirmedAssignments()
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
      if Superwall.options.paywalls.shouldPreload {
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
  /// A developer can disable preloading of paywalls by setting ``SuperwallOptions/shouldPreloadPaywalls``.
  private func preloadPaywalls() {
    guard Superwall.options.paywalls.shouldPreload else {
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
    let triggersToPreload = config.triggers.filter { triggerNames.contains($0.eventName) }
    let triggerPaywallIdentifiers = getTreatmentPaywallIds(from: triggersToPreload)
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by triggers.
  private func preloadPaywalls(withIdentifiers paywallIdentifiers: Set<String>) {
    for identifier in paywallIdentifiers {
      Task {
        let request = PaywallRequest(responseIdentifiers: .init(paywallId: identifier))
        _ = try? await paywallManager.getPaywallViewController(
          from: request,
          cached: true
        )
      }
    }
  }

  /// This sends product data back to the dashboard
  private func executePostback(from config: Config) async {
    guard config.featureFlags.enablePostback else {
      return
    }
    let oneSecond = UInt64(1_000_000_000)
    let nanosecondDelay = UInt64(config.postback.postbackDelay) * oneSecond

    do {
      try await Task.sleep(nanoseconds: nanosecondDelay)

      let productIds = config.postback.productsToPostBack.map { $0.identifier }

      let products = try await StoreKitManager.shared.getProducts(withIds: productIds)
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
