//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/08/2022.
//

import Foundation

class TriggerDelayManager {
  static let shared = TriggerDelayManager()
  /// Returns `true` if config doesn't exist yet.
  var hasDelay: Bool {
    // TODO: DOUBLE CHECK THIS:
    let configUnavailable = ConfigManager.shared.config == nil
    let blockingAssignmentWaiting = Storage.shared.preConfigAssignmentCall != nil
    return configUnavailable || blockingAssignmentWaiting
  }

  func handleDelayedContent(
    storage: Storage = .shared,
    configManager: ConfigManager = .shared
  ) {
    if let preConfigAssignmentCall = storage.preConfigAssignmentCall {
      if preConfigAssignmentCall.isBlocking {
        configManager.loadAssignments { [weak self] in
          storage.preConfigAssignmentCall = nil
          self?.fireDelayedTriggers()
        }
      } else {
        configManager.loadAssignments()
        storage.preConfigAssignmentCall = nil
        fireDelayedTriggers()
      }
    } else {
      fireDelayedTriggers()
    }
  }

  func fireDelayedTriggers(
    storage: Storage = .shared,
    paywall: Paywall = .shared
  ) {
    storage.triggersFiredPreConfig.forEach { trigger in
      switch trigger.presentationInfo.triggerType {
      case .implicit:
        guard let eventData = trigger.presentationInfo.eventData else {
          return
        }
        paywall.handleImplicitTrigger(forEvent: eventData)
      case .explicit:
        Paywall.internallyPresent(
          trigger.presentationInfo,
          on: trigger.viewController,
          ignoreSubscriptionStatus: trigger.ignoreSubscriptionStatus,
          onPresent: trigger.onPresent,
          onDismiss: trigger.onDismiss,
          onSkip: trigger.onFail
        )
      }
    }
    storage.clearPreConfigTriggers()
  }
}
