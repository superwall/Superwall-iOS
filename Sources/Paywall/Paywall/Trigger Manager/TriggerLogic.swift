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
    experimentGroupId: String,
    experimentId: String,
    variantId: String
  )
  case noRuleMatch
  case presentTriggerPaywall(
    experimentGroupId: String,
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
    triggers: [String: Trigger]
  ) -> Outcome {
    if let trigger = triggers[event.name] {
      if let rule = Self.findRule(
        in: event,
        trigger: trigger
      ) {
        let confirmableAssignments = getConfirmableAssignments(forRule: rule)

        switch rule.variant {
        case .holdout(let holdout):
          return Outcome(
            confirmableAssignments: confirmableAssignments,
            result: .holdout(
              experimentGroupId: rule.experimentGroupId,
              experimentId: rule.experimentId,
              variantId: holdout.variantId
            )
          )
        case .treatment(let treatment):
          return Outcome(
            confirmableAssignments: confirmableAssignments,
            result: .presentTriggerPaywall(
              experimentGroupId: rule.experimentGroupId,
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
      return Outcome(result: .unknownEvent)
    }
  }

  private static func findRule(
    in event: EventData,
    trigger: Trigger
  ) -> TriggerRule? {
    for rule in trigger.rules {
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
