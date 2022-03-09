//
//  TriggerLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum HandleEventResult {
  case unknownEvent
  case holdout(
    experimentId: String,
    variantId: String
  )
  case noRuleMatch
  case presentV1
  case presentIdentifier(
    experimentId: String,
    variantId: String,
    paywallIdentifier: String
  )
}

enum TriggerLogic {
  struct Outcome {
    var confirmableAssignments: ConfirmableAssignments?
    var result: HandleEventResult
  }

  static func outcome(
    forEvent event: EventData,
    v1Triggers: Set<String>,
    v2Triggers: [String: TriggerV2]
  ) -> Outcome {
    if let triggerV2 = v2Triggers[event.name] {
      if let rule = Self.findRule(
        in: event,
        v2Trigger: triggerV2
      ) {
        let confirmableAssignments = getConfirmableAssignments(forRule: rule)

        switch rule.variant {
        case .holdout(let holdout):
          return Outcome(
            confirmableAssignments: confirmableAssignments,
            result: .holdout(
              experimentId: rule.experimentId,
              variantId: holdout.variantId
            )
          )
        case .treatment(let treatment):
          return Outcome(
            confirmableAssignments: confirmableAssignments,
            result: .presentIdentifier(
              experimentId: rule.experimentId,
              variantId: treatment.variantId,
              paywallIdentifier: treatment.paywallIdentifier
            )
          )
        }
      } else {
        return Outcome(result: .noRuleMatch)
      }
    } else {
      if v1Triggers.contains(event.name) {
        return Outcome(result: .presentV1)
      }
      return Outcome(result: .unknownEvent)
    }
  }

  private static func findRule(
    in event: EventData,
    v2Trigger: TriggerV2
  ) -> TriggerRule? {
    for rule in v2Trigger.rules {
      if ExpressionEvaluator.evaluateExpression(
        expression: rule.expression,
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
            experimentId: rule.experimentId,
            variantId: rule.variantId
          )
        ]
      )
      return confirmableAssignments
    }
  }
}
