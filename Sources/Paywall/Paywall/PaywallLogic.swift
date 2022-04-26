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
    case disallowedEventAsTrigger
    case dontTriggerPaywall
  }
  static func canTriggerPaywall(
    eventName: String,
    v1Triggers: Set<String>,
    v2Triggers: Set<String>,
    isPaywallPresented: Bool
  ) -> Outcome {
    if isPaywallPresented {
      return .dontTriggerPaywall
    }

    let isV1Trigger = v1Triggers.contains(eventName)
    let isV2Trigger = v2Triggers.contains(eventName)

    guard isV1Trigger || isV2Trigger else {
      return .dontTriggerPaywall
    }

    let allowedSuperwallEvents = Set(["app_install", "session_start", "app_launch"])
    let isAllowedTrigger = allowedSuperwallEvents.contains(eventName)
    let isNotSuperwallEvent = Paywall.EventName(rawValue: eventName) == nil

    if isAllowedTrigger || isNotSuperwallEvent {
      return .triggerPaywall
    } else {
      return .disallowedEventAsTrigger
    }
  }

  static func trackAppInstall(
    trackEvent: (Trackable) -> TrackingResult = Paywall.track
  ) {
    let appInstall = SuperwallEvent.AppInstall()
    guard UserDefaults.standard.bool(forKey: appInstall.rawName) == false else {
      return
    }
    _ = trackEvent(appInstall)
    UserDefaults.standard.set(true, forKey: appInstall.rawName)
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
