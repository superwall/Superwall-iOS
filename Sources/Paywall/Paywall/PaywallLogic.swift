//
//  PaywallLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum PaywallLogic {
  enum Outcome {
    case triggerPaywall
    case internalEventAsTrigger
    case dontTriggerPaywall
  }
  static func canTriggerPaywall(
    eventName: String,
    triggers: Set<String>,
    isPaywallPresented: Bool
  ) -> Outcome {
    if isPaywallPresented {
      return .dontTriggerPaywall
    }

    let isV1Trigger = triggers.contains(eventName)
    let isV2Trigger = triggers.contains(eventName)

    guard isV1Trigger || isV2Trigger else {
      return .dontTriggerPaywall
    }

    let allowedInternalEvents = Set(["app_install", "session_start", "app_launch"])
    let isAllowedTrigger = allowedInternalEvents.contains(eventName)
    let isNotInternalEvent = InternalEventName(rawValue: eventName) == nil

    if isAllowedTrigger || isNotInternalEvent {
      return .triggerPaywall
    } else {
      return .internalEventAsTrigger
    }
  }

  static func sessionDidStart(
    _ lastAppClose: Date?
  ) -> Bool {
    let twoMinsAgo = 120.0
    
    let delta: TimeInterval
    if let lastAppClose = lastAppClose {
      delta = -lastAppClose.timeIntervalSinceNow
    } else {
      delta = twoMinsAgo + 1
    }

    return delta > twoMinsAgo
  }
}
