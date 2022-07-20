//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/06/2022.
//

import UIKit

final class ConfigManager {
  var didFetchConfig = !Storage.shared.configRequestId.isEmpty
  var options: PaywallOptions
  private let storage: Storage
  private let network: Network

  init(
    options: PaywallOptions = PaywallOptions(),
    storage: Storage = Storage.shared,
    network: Network = Network.shared
  ) {
    self.options = options
    self.storage = storage
    self.network = network

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  func fetchConfiguration() {
    let requestId = UUID().uuidString
    DispatchQueue.main.async {
      Network.shared.getConfig(withRequestId: requestId) { [weak self] result in
        guard let self = self else {
          return
        }
        switch result {
        case .success(let config):
          Storage.shared.addConfig(config, withRequestId: requestId)
          SessionEventsManager.shared.triggerSession.createSessions(from: config)
          self.didFetchConfig = true
          config.cache()

          Storage.shared.triggersFiredPreConfig.forEach { trigger in
            switch trigger.presentationInfo.triggerType {
            case .implicit:
              guard let eventData = trigger.presentationInfo.eventData else {
                return
              }
              Paywall.shared.handleImplicitTrigger(forEvent: eventData)
            case .explicit:
              Paywall.internallyPresent(
                trigger.presentationInfo,
                on: trigger.viewController,
                ignoreSubscriptionStatus: trigger.ignoreSubscriptionStatus,
                onPresent: trigger.onPresent,
                onDismiss: trigger.onDismiss,
                onFail: trigger.onFail
              )
            }
          }
          Storage.shared.clearPreConfigTriggers()
        case .failure(let error):
          Logger.debug(
            logLevel: .error,
            scope: .paywallCore,
            message: "Failed to Fetch Configuration",
            info: nil,
            error: error
          )
          self.didFetchConfig = true
        }
      }
    }
  }

  @objc private func applicationDidBecomeActive() {
    guard let configRequest = storage.configRequest else {
      return
    }
    network.getConfig(
      withRequestId: configRequest.id,
      completion: configRequest.completion
    )
    storage.configRequest = nil
  }
}
