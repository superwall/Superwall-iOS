//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/08/2022.
//

import Foundation

struct ConfirmableAssignment {
  let experimentId: Experiment.ID
  let variant: Experiment.Variant
}

enum AssignmentLogic {
  struct Outcome {
    var confirmableAssignment: ConfirmableAssignment?
    var result: TriggerResult
  }

  /// Determines whether there is an assignment to confirm based on the rule.
  ///
  /// - Returns: An assignment to confirm, if available.
  static func getOutcome(
    forEvent event: EventData,
    triggers: [String: Trigger],
    configManager: ConfigManager = .shared
  ) -> Outcome {
    if let trigger = triggers[event.name] {
      if let rule = TriggerLogic.findMatchingRule(
        for: event,
        withTrigger: trigger
      ) {
        let variant: Experiment.Variant
        var confirmableAssignment: ConfirmableAssignment?

        // For a matching rule there will be an unconfirmed or confirmed variant assignment (either in memory or on disk respectively).
        if let unconfirmedVariant = configManager.unconfirmedAssignments[rule.experiment.id] {
          confirmableAssignment = ConfirmableAssignment(
            experimentId: rule.experiment.id,
            variant: unconfirmedVariant
          )
          variant = unconfirmedVariant
        } else {
          let confirmedAssignments = Storage.shared.getConfirmedAssignments()
          guard let confirmedVariant = confirmedAssignments[rule.experiment.id] else {
            // TODO: Review this outcome.
            // This should never be hit, but in the case it does, we'll return unknownEvent.
            return Outcome(result: .unknownEvent)
          }
          variant = confirmedVariant
        }

        switch variant.type {
        case .holdout:
          return Outcome(
            confirmableAssignment: confirmableAssignment,
            result: .holdout(
              experiment: Experiment(
                id: rule.experiment.id,
                groupId: rule.experiment.groupId,
                variant: variant
              )
            )
          )
        case .treatment:
          return Outcome(
            confirmableAssignment: confirmableAssignment,
            result: .paywall(
              experiment: Experiment(
                id: rule.experiment.id,
                groupId: rule.experiment.groupId,
                variant: variant
              )
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
}
