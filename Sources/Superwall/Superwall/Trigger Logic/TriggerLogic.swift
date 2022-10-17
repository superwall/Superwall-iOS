//
//  TriggerLogic.swift
//  Superwall
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

  static func getTriggersByEventName(from triggers: Set<Trigger>) -> [String: Trigger] {
    let triggersDictionary = triggers.reduce([String: Trigger]()) { result, trigger in
      var result = result
      result[trigger.eventName] = trigger
      return result
    }
    return triggersDictionary
  }
}
