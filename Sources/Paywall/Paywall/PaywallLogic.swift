//
//  PaywallLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum PaywallLogic {
  static func canTriggerPaywall(
    eventName: String,
    triggers: Set<String>,
    isPaywallPresented: Bool
  ) -> Bool {
    if isPaywallPresented {
      return false
    }

    let isV1Trigger = triggers.contains(eventName)
    let isV2Trigger = triggers.contains(eventName)

    guard isV1Trigger || isV2Trigger else {
      return false
    }

    let allowedInternalEvents = Set(["app_install", "session_start", "app_launch"])
    let isAllowedTrigger = allowedInternalEvents.contains(eventName)
    let isNotInternalEvent = InternalEventName(rawValue: eventName) == nil

    if isAllowedTrigger || isNotInternalEvent {
      return true
    } else {
      return false
    }
  }
}
