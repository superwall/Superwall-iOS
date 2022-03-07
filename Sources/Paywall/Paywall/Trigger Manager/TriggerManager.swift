//
//  TriggerManager.swift
//  Superwall
//
//  Created by Brian Anglin on 2/21/22.
//

import Foundation
import UIKit

enum HandleEventResult {
  case unknownEvent
  // experimentId, variantId
  case holdout(String, String)
  // None of the rules match
  case noRuleMatch
  // Present v1
  case presentV1
  // experimentId, variantId, paywallIdentifier
  case presentIdentifier(String, String, String)
}

enum TriggerManager {
  static func handleEvent(
    eventName: String,
    eventData: EventData?
  ) -> HandleEventResult {
    // If we have the config response, all valid triggers should be in response
    let outcome = TriggerLogic.outcome(
      forEventName: eventName,
      eventData: eventData,
      v1Triggers: CacheManager.shared.triggers,
      v2Triggers: CacheManager.shared.v2Triggers
    )

    if let confirmedAssignments = outcome.confirmedAssignments {
      Network.shared.sendConfirmedAssignments(
        confirmedAssignments,
        completion: nil
      )
    }

    return outcome.result
  }
}
