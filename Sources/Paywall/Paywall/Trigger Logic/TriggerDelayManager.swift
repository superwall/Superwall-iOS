//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/08/2022.
//
// swiftlint:disable empty_count

import Foundation

final class TriggerDelayManager {
  static let shared = TriggerDelayManager()
  var hasDelay: Bool {
    return count != 0
  }
  let configDispatchGroup = DispatchGroup()
  let assignmentDispatchGroup = DispatchGroup()
  private var count = 0

  func enterConfigDispatchQueue() {
    configDispatchGroup.enter()
    count += 1
  }

  func leaveConfigDispatchQueue() {
    configDispatchGroup.leave()
    count -= 1
  }

  func enterAssignmentDispatchQueue() {
    assignmentDispatchGroup.enter()
    count += 1
  }

  func leaveAssignmentDispatchQueue() {
    assignmentDispatchGroup.leave()
    count -= 1
  }

  func fireDelayedTriggers() {
    configDispatchGroup.notify(queue: .main) { [weak self] in
      self?.assignmentDispatchGroup.notify(queue: .main) {
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
              onSkip: trigger.onFail
            )
          }
        }
        Storage.shared.clearPreConfigTriggers()
      }
    }
  }
}
