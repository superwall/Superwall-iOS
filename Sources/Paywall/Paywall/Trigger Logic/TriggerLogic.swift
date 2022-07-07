//
//  TriggerLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum TriggerLogic {
  struct Outcome {
    var confirmableAssignments: ConfirmableAssignments?
    var result: TriggerResult
  }

  static func assignmentOutcome(
    forEvent event: EventData,
    triggers: [String: Trigger]
  ) -> Outcome {
    if let trigger = triggers[event.name] {
      if let rule = Self.findRule(
        in: event,
        trigger: trigger
      ) {
        let confirmableAssignments = getConfirmableAssignments(forRule: rule)

        switch rule.experiment.variant.type {
        case .holdout:
          return Outcome(
            confirmableAssignments: confirmableAssignments,
            result: .holdout(experiment: rule.experiment)
          )
        case .treatment:
          return Outcome(
            confirmableAssignments: confirmableAssignments,
            result: .paywall(experiment: rule.experiment)
          )
        }
      } else {
        return Outcome(result: .noRuleMatch)
      }
    } else {
      return Outcome(result: .unknownEvent)
    }
  }

  private static func findRule(
    in event: EventData,
    trigger: Trigger
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

  private static func getConfirmableAssignments(
    forRule rule: TriggerRule
  ) -> ConfirmableAssignments? {
    if rule.isAssigned {
      return nil
    } else {
      let confirmableAssignments = ConfirmableAssignments(
        assignments: [
          Assignment(
            experimentId: rule.experiment.id,
            variantId: rule.experiment.variant.id
          )
        ]
      )
      return confirmableAssignments
    }
  }
}
