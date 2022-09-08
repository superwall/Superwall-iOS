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
    let configUnavailable = ConfigManager.shared.config == nil
    var blockingAssignmentWaiting = false
    if let preConfigAssignmentCall = preConfigAssignmentCall {
      blockingAssignmentWaiting = preConfigAssignmentCall.isBlocking
    }
    return configUnavailable || blockingAssignmentWaiting
  }
  private(set) var triggersFiredPreConfig: [PreConfigTrigger] = []
  private(set) var preConfigAssignmentCall: PreConfigAssignmentCall?
  var appUserIdAfterReset: String?

  func handleDelayedContent(
    storage: Storage = .shared,
    configManager: ConfigManager = .shared
  ) {
    // If the user has called identify with a diff ID, we call reset.
    // Then we wait until config has returned before identifying again.
    if let appUserIdAfterReset = appUserIdAfterReset {
      storage.identify(with: appUserIdAfterReset)
      self.appUserIdAfterReset = nil
    }

    if let preConfigAssignmentCall = preConfigAssignmentCall {
      if preConfigAssignmentCall.isBlocking {
        configManager.loadAssignments { [weak self] in
          self?.preConfigAssignmentCall = nil
          self?.fireDelayedTriggers()
        }
      } else {
        configManager.loadAssignments()
        self.preConfigAssignmentCall = nil
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
    triggersFiredPreConfig.forEach { trigger in
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
    clearPreConfigTriggers()
  }

  func cachePreConfigTrigger(_ trigger: PreConfigTrigger) {
    triggersFiredPreConfig.append(trigger)
  }

  func clearPreConfigTriggers() {
    triggersFiredPreConfig.removeAll()
  }

  func cachePreConfigAssignmentCall(_ assignmentCall: PreConfigAssignmentCall) {
    preConfigAssignmentCall = assignmentCall
  }

  func removePreConfigAssignmentCall() {
    preConfigAssignmentCall = nil
  }
}
