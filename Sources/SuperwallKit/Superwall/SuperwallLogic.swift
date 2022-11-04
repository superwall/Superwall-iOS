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
    event: Trackable,
    triggers: Set<String>,
    isPaywallPresented: Bool
  ) -> Outcome {
    if let event = event as? TrackableSuperwallEvent,
       case .deepLink(url: _) = event.superwallEvent {
      return .deepLinkTrigger
    }

    if isPaywallPresented {
      return .dontTriggerPaywall
    }
    guard triggers.contains(event.rawName) else {
      return .dontTriggerPaywall
    }

    return .triggerPaywall
  }
}
