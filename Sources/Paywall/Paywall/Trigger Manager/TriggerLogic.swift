//
//  TriggerLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum TriggerLogic {
  struct Outcome {
    var confirmAssignments: ConfirmAssignments?
    var result: HandleEventResult
  }

  static func triggerOutcome(
    forEventName eventName: String,
    eventData: EventData?,
    v1Triggers: Set<String>,
    v2Triggers: [String: TriggerV2]
  ) -> Outcome {
    if let triggerV2 = v2Triggers[eventName] {
      if let rule = Self.findRule(
        in: eventData,
        v2Trigger: triggerV2
      ) {
        let confirmAssignments = getConfirmAssignments(forRule: rule)

        switch rule.variant {
        case .holdout(let holdout):
          return Outcome(
            confirmAssignments: confirmAssignments,
            result: .holdout(rule.experimentId, holdout.variantId)
          )
        case .treatment(let treatment):
          return Outcome(
            confirmAssignments: confirmAssignments,
            result: .presentIdentifier(
              rule.experimentId,
              treatment.variantId,
              treatment.paywallIdentifier
            )
          )
        }
      } else {
        return Outcome(result: .noRuleMatch)
      }
    } else {
      if v1Triggers.contains(eventName) {
        return Outcome(result: .presentV1)
      }
      return Outcome(result: .unknownEvent)
    }
  }

  private static func findRule(
    in eventData: EventData?,
    v2Trigger: TriggerV2
  ) -> TriggerRule? {
    for rule in v2Trigger.rules {
      if ExpressionEvaluator.evaluateExpression(
        expression: rule.expression,
        eventData: eventData
      ) {
        return rule
      }
    }
    return nil
  }

  private static func getConfirmAssignments(
    forRule rule: TriggerRule
  ) -> ConfirmAssignments? {
    if rule.assigned {
      return nil
    } else {
      let confirmAssignment = ConfirmAssignments(
        assignments: [
          Assignment(
            experimentId: rule.experimentId,
            variantId: rule.variantId
          )
        ]
      )
      return confirmAssignment
    }
  }
}
