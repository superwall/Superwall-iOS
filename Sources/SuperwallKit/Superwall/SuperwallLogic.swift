//
//  PaywallLogic.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum SuperwallLogic {
  enum Outcome {
    case triggerPaywall
    case deepLinkTrigger
    case disallowedEventAsTrigger
    case dontTriggerPaywall
  }
  static func canTriggerPaywall(
    eventName: String,
    triggers: Set<String>,
    isPaywallPresented: Bool
  ) -> Outcome {
    if let superwallEvent = SuperwallEvent(rawValue: eventName),
      superwallEvent == .deepLink {
      return .deepLinkTrigger
    }

    if isPaywallPresented {
      return .dontTriggerPaywall
    }
    guard triggers.contains(eventName) else {
      return .dontTriggerPaywall
    }

    if let superwallEvent = SuperwallEvent(rawValue: eventName) {
      if superwallEvent.canImplicitlyTriggerPaywall {
        return .triggerPaywall
      } else {
        return .disallowedEventAsTrigger
      }
    } else {
      return .triggerPaywall
    }
  }
}
