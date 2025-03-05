//
//  File.swift
//
//
//  Created by Yusuf Tör on 09/08/2022.
//

import Foundation

struct AudienceFilterEvaluationOutcome {
  var assignment: Assignment?
  var unsavedOccurrence: TriggerAudienceOccurrence?
  var triggerResult: InternalTriggerResult
}

enum RuleMatchOutcome {
  case matched(MatchedItem)
  case noMatchingAudiences([UnmatchedAudience])
}

struct AudienceLogic {
  unowned let configManager: ConfigManager
  unowned let storage: Storage
  unowned let factory: AudienceFilterAttributesFactory

  /// Determines the outcome of a placement based on given triggers. It also determines
  /// whether there is an assignment to confirm based on the audience filter.
  ///
  /// This first finds a trigger for a given placement name. Then it determines whether any of the
  /// audiences of the triggers match for that placement.
  /// It takes that audience filter and checks the disk for a paywall variant assignment for the audience's experiment ID.
  /// Then it returns the result of the placement given the assignment.
  ///
  /// - Parameters:
  ///   - placement: The tracked placement.
  ///   - triggers: The triggers from config.
  /// - Returns: The result of evaluating the audience filter.
  func evaluateAudienceFilters(
    forPlacement placement: PlacementData,
    triggers: [String: Trigger]
  ) async -> AudienceFilterEvaluationOutcome {
    // Ensure the trigger exists for the placement.
    guard let trigger = triggers[placement.name] else {
      return AudienceFilterEvaluationOutcome(
        triggerResult: .placementNotFound
      )
    }

    // Find a matching rule for the placement using the trigger.
    let ruleMatchOutcome = await findMatchingRule(
      for: placement,
      withTrigger: trigger
    )

    let matchedRuleItem: MatchedItem
    switch ruleMatchOutcome {
    case .matched(let item):
      matchedRuleItem = item
    case .noMatchingAudiences(let unmatchedAudiences):
      return AudienceFilterEvaluationOutcome(
        triggerResult: .noAudienceMatch(unmatchedAudiences)
      )
    }

    let rule = matchedRuleItem.audience

    guard let assignment = storage.getAssignments()
      .first(where: { $0.experimentId == rule.experiment.id })
    else {
      // If no variant in memory or disk, return an error.
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Not Found",
          value: "There isn't a paywall configured to show in this context",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWPaywallNotFound",
        code: 404,
        userInfo: userInfo
      )
      return AudienceFilterEvaluationOutcome(triggerResult: .error(error))
    }

    let variant = assignment.variant
    let experiment = Experiment(
      id: rule.experiment.id,
      groupId: rule.experiment.groupId,
      variant: variant
    )

    // Return the appropriate outcome based on the variant type.
    switch variant.type {
    case .holdout:
      return AudienceFilterEvaluationOutcome(
        assignment: assignment,
        unsavedOccurrence: matchedRuleItem.unsavedOccurrence,
        triggerResult: .holdout(experiment)
      )
    case .treatment:
      return AudienceFilterEvaluationOutcome(
        assignment: assignment,
        unsavedOccurrence: matchedRuleItem.unsavedOccurrence,
        triggerResult: .paywall(experiment)
      )
    }
  }

  func findMatchingRule(
    for placement: PlacementData,
    withTrigger trigger: Trigger
  ) async -> RuleMatchOutcome {
    var unmatchedAudiences: [UnmatchedAudience] = []

    for audience in trigger.audiences {
      let outcome = await configManager.expressionEvaluator.evaluateExpression(
        fromAudienceFilter: audience,
        placementData: placement
      )
      switch outcome {
      case .match(let item):
        return .matched(item)
      case .noMatch(let unmatchedAudience):
        unmatchedAudiences.append(unmatchedAudience)
      }
    }

    return .noMatchingAudiences(unmatchedAudiences)
  }
}
