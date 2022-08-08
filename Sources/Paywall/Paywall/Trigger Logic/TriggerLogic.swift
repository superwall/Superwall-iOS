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
        let variant: Experiment.Variant
        let assignments = Storage.shared.getAssignments()

        if let assignment = assignments.first(where: { $0.experimentId == rule.experiment.id }),
          let variantOption = rule.experiment.variants.first(where: { $0.id == assignment.variantId }) {
          variant = .init(
            id: variantOption.id,
            type: variantOption.type,
            paywallId: variantOption.paywallId
          )
        } else {
          variant = TriggerRuleLogic.chooseVariant(from: Storage.shared.co)
        }
        // Cache the response. On trigger fire, check the confirmed assignment cache for experiment id, if it's not in there choose a variant and then store to local cache, as well as send off to server.
        // When confirmed assignments is sent, it returns the current assignments. If it no lon


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
