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
    triggers: Set<String>,
    isPaywallPresented: Bool
  ) -> Outcome {
    if isPaywallPresented {
      return .dontTriggerPaywall
    }
    guard triggers.contains(eventName) else {
      return .dontTriggerPaywall
    }

    if let superwallEvent = Paywall.EventName(rawValue: eventName) {
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
