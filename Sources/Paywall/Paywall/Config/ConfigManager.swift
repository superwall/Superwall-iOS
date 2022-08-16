//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/06/2022.
//

import UIKit

final class ConfigManager {
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
    let availableVariantIds = Set(triggers.flatMap { $0.rules.flatMap { $0.experiment.variants.map { $0.id } } })

    // Loop through each trigger and each of its rules.
    for trigger in triggers {
      for rule in trigger.rules {
        // Check whether we have already chosen a variant for the experiment on disk.
        if let confirmedVariant = confirmedAssignments[rule.experiment.id] {
          // If one exists, check it's still in the available variants, otherwise reroll.
          if !availableVariantIds.contains(confirmedVariant.id) {
            guard let variant = try? TriggerRuleLogic.chooseVariant(from: rule.experiment.variants) else {
              continue
            }
            unconfirmedAssignments[rule.experiment.id] = variant
            confirmedAssignments[rule.experiment.id] = nil
          }
        } else {
          // No variant found on disk so dice roll to choose a variant and store in memory as an unconfirmed assignment.
          guard let variant = try? TriggerRuleLogic.chooseVariant(from: rule.experiment.variants) else {
            continue
          }
          unconfirmedAssignments[rule.experiment.id] = variant
        }
      }
    }

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
        for assignment in assignments {
          // Get the trigger with the matching experiment ID
          guard let trigger = triggers.first(
            where: { $0.rules.contains(where: { $0.experiment.id == assignment.experimentId }) }
          ) else {
            continue
          }
          // Get the variant with the matching variant ID
          guard let variantOption = trigger.rules.compactMap({
            $0.experiment.variants.first { $0.id == assignment.variantId }
          }).first else {
            continue
          }

          // Save this to disk, remove any unconfirmed assignments with the same experiment ID.
          confirmedAssignments[assignment.experimentId] = Experiment.Variant(
            id: variantOption.id,
            type: variantOption.type,
            paywallId: variantOption.paywallId
          )
          self.unconfirmedAssignments[assignment.experimentId] = nil
        }
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
    guard let paywallId = paywallId else {
      return nil
    }
    guard let config = config else {
      return nil
    }

    // If the available locales contains the exact device locale, load the response the old way.
    if config.locales.contains(DeviceHelper.shared.locale) {
      return nil
    } else {
      let shortLocale = String(DeviceHelper.shared.locale.split(separator: "_")[0])

      // Otherwise, if the shortened locale contains "en", load the paywall responses from static config.
      // Same if we can't find any matching locale in available locales.
      if shortLocale == "en" || !config.locales.contains(shortLocale) {
        return config.paywallResponses.first { $0.identifier == paywallId }
      } else {
        return nil
      }
    }
  }

  /*
   Make sure it doesn't preload variants that aren't in static config.
   */
  private func getAllTreatmentPaywallIds() -> Set<String> {
    guard let triggers = config?.triggers else {
      return []
    }
    // TODO: Extract confirmed assignments into memory to reduce load time.
    var confirmedAssignments = Storage.shared.getConfirmedAssignments()

    // Don't preload any experiment IDs that are on disk but no longer in static config.
    // This could happen when a campaign has been archived.
    let confirmedExperimentIds = Set(confirmedAssignments.keys)
    let triggerExperimentIds = Set(triggers.flatMap { $0.rules.map { $0.experiment.id } })
    let oldExperimentIds = confirmedExperimentIds.subtracting(triggerExperimentIds)
    for id in oldExperimentIds {
      confirmedAssignments[id] = nil
    }

    let confirmedVariants = [Experiment.Variant](confirmedAssignments.values)
    let unconfirmedVariants = [Experiment.Variant](unconfirmedAssignments.values)
    let mergedVariants = confirmedVariants + unconfirmedVariants
    var identifiers: Set<String> = []

    for variant in mergedVariants {
      if variant.type == .treatment,
        let paywallId = variant.paywallId {
        identifiers.insert(paywallId)
      }
    }

    return identifiers
  }

  private func getTreatmentPaywallIds(from triggers: Set<Trigger>) -> Set<String> {
    // TODO: Extract confirmed assignments into memory to reduce load time.
    let confirmedAssignments = Storage.shared.getConfirmedAssignments()

    let mergedAssignments = confirmedAssignments.merging(unconfirmedAssignments)
    let triggerExperimentIds = triggers.flatMap { $0.rules.map { $0.experiment.id } }

    var identifiers: Set<String> = []
    for experimentId in triggerExperimentIds {
      guard let variant = mergedAssignments[experimentId] else {
        continue
      }
      if variant.type == .treatment,
        let paywallId = variant.paywallId {
        identifiers.insert(paywallId)
      }
    }

    return identifiers
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
  /// A developer can disable preloading of paywalls by setting ``Paywall/Paywall/shouldPreloadPaywalls``
  private func cacheConfig() {
    if Paywall.options.shouldPreloadPaywalls {
      preloadAllPaywalls()
    } else {
      preloadAllPaywallResponses()
    }
    executePostback()
  }

  /// Preloads only the paywall responses
  func preloadAllPaywallResponses() {
    let triggerPaywallIdentifiers = getAllTreatmentPaywallIds()
    for identifier in triggerPaywallIdentifiers {
      PaywallResponseManager.shared.getResponse(
        withIdentifiers: .init(paywallId: identifier)) { _ in }
    }
  }

  /// Preloads paywalls referenced by triggers.
  func preloadAllPaywalls() {
    let triggerPaywallIdentifiers = getAllTreatmentPaywallIds()
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
