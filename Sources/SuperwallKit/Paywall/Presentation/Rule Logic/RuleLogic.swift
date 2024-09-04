//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/08/2022.
//
// swiftlint:disable function_body_length

import Foundation

struct ConfirmableAssignment: Equatable {
  let experimentId: Experiment.ID
  let variant: Experiment.Variant
}

struct RuleEvaluationOutcome {
  var confirmableAssignment: ConfirmableAssignment?
  var unsavedOccurrence: TriggerRuleOccurrence?
  var triggerResult: InternalTriggerResult
}

enum RuleMatchOutcome {
  case matched(MatchedItem)
  case noMatchingRules([UnmatchedRule])
}

struct RuleLogic {
  unowned let configManager: ConfigManager
  unowned let storage: Storage
  unowned let factory: RuleAttributesFactory

  /// Determines the outcome of a placement based on given triggers. It also determines
  /// whether there is an assignment to confirm based on the audience filter.
  ///
  /// This first finds a trigger for a given placement name. Then it determines whether any of the
  /// rules of the triggers match for that placement.
  /// It takes that audience filter and checks the disk for a confirmed variant assignment for the audience's
  /// experiment ID. If there isn't one, it checks the unconfirmed assignments.
  /// Then it returns the result of the placement given the assignment.
  ///
  /// - Parameters:
  ///   - placement: The tracked placement
  ///   - triggers: The triggers from config.
  ///   - configManager: A `ConfigManager` object used for dependency injection.
  ///   - storage: A `Storage` object used for dependency injection.
  ///   - isPreemptive: A boolean that indicates whether the rule is being preemptively
  ///   evaluated. Setting this to `true` prevents the rule's occurrence count from being incremented
  ///   in Core Data.
  /// - Returns: An assignment to confirm, if available.
  func evaluateRules(
    forPlacement placement: PlacementData,
    triggers: [String: Trigger]
  ) async -> RuleEvaluationOutcome {
    guard let trigger = triggers[placement.name] else {
      return RuleEvaluationOutcome(triggerResult: .placementNotFound)
    }

    let ruleMatchOutcome = await findMatchingRule(
      for: placement,
      withTrigger: trigger
    )

    let matchedRuleItem: MatchedItem

    switch ruleMatchOutcome {
    case .matched(let item):
      matchedRuleItem = item
    case .noMatchingRules(let unmatchedRules):
      return.init(triggerResult: .noAudienceMatch(unmatchedRules))
    }

    let variant: Experiment.Variant
    var confirmableAssignment: ConfirmableAssignment?
    let rule = matchedRuleItem.rule
    // For a matching rule there will be an unconfirmed (in-memory) or confirmed (on disk) variant assignment.
    // First check the disk, otherwise check memory.
    let confirmedAssignments = storage.getConfirmedAssignments()
    if let confirmedVariant = confirmedAssignments[rule.experiment.id] {
      variant = confirmedVariant
    } else if let unconfirmedVariant = configManager.unconfirmedAssignments[rule.experiment.id] {
      confirmableAssignment = ConfirmableAssignment(
        experimentId: rule.experiment.id,
        variant: unconfirmedVariant
      )
      variant = unconfirmedVariant
    } else {
      // If no variant in memory or disk
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
      return RuleEvaluationOutcome(triggerResult: .error(error))
    }

    switch variant.type {
    case .holdout:
      return RuleEvaluationOutcome(
        confirmableAssignment: confirmableAssignment,
        unsavedOccurrence: matchedRuleItem.unsavedOccurrence,
        triggerResult: .holdout(
          Experiment(
            id: rule.experiment.id,
            groupId: rule.experiment.groupId,
            variant: variant
          )
        )
      )
    case .treatment:
      return RuleEvaluationOutcome(
        confirmableAssignment: confirmableAssignment,
        unsavedOccurrence: matchedRuleItem.unsavedOccurrence,
        triggerResult: .paywall(
          Experiment(
            id: rule.experiment.id,
            groupId: rule.experiment.groupId,
            variant: variant
          )
        )
      )
    }
  }

  func findMatchingRule(
    for placement: PlacementData,
    withTrigger trigger: Trigger
  ) async -> RuleMatchOutcome {
    let expressionEvaluator = ExpressionEvaluator(
      storage: storage,
      factory: factory
    )

    var unmatchedRules: [UnmatchedRule] = []

    for rule in trigger.rules {
      let outcome = await expressionEvaluator.evaluateExpression(
        fromAudienceFilter: rule,
        placementData: placement
      )

      switch outcome {
      case .match(let item):
        return .matched(item)
      case .noMatch(let noRuleMatch):
        unmatchedRules.append(noRuleMatch)
      }
    }

    return .noMatchingRules(unmatchedRules)
  }
}
