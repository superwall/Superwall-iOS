//
//  TriggerLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum TriggerLogic {
  static func findMatchingRule(
    for event: EventData,
    withTrigger trigger: Trigger
  ) -> TriggerRule? {
    for rule in trigger.rules {
      if ExpressionEvaluator.evaluateExpression(
        fromRule: rule,
        eventData: event
      ) {
        return rule
      }
    }
    return nil
  }
}
