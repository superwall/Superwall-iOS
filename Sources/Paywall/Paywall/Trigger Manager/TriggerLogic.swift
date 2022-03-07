//
//  TriggerLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum TriggerLogic {
  struct Outcome {
    var confirmedAssignments: ConfirmedAssignments?
    var result: HandleEventResult
  }

  static func outcome(
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
        let confirmedAssignments = getConfirmedAssignments(forRule: rule)

        switch rule.variant {
        case .holdout(let holdout):
          return Outcome(
            confirmedAssignments: confirmedAssignments,
            result: .holdout(rule.experimentId, holdout.variantId)
          )
        case .treatment(let treatment):
          return Outcome(
            confirmedAssignments: confirmedAssignments,
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

  private static func getConfirmedAssignments(
    forRule rule: TriggerRule
  ) -> ConfirmedAssignments? {
    if rule.assigned {
      return nil
    } else {
      let confirmedAssignments = ConfirmedAssignments(
        assignments: [
          Assignment(
            experimentId: rule.experimentId,
            variantId: rule.variantId
          )
        ]
      )
      return confirmedAssignments
    }
  }
}
