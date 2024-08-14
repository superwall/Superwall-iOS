//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/08/2024.
//

import Foundation

struct ExpressionLogic {
  unowned let storage: Storage

  func tryToMatchOccurrence(
    from rule: TriggerRule,
    expressionMatched: Bool
  ) async -> TriggerRuleOutcome {
    if expressionMatched {
      guard let occurrence = rule.occurrence else {
        Logger.debug(
          logLevel: .debug,
          scope: .paywallPresentation,
          message: "No occurrence parameter found for trigger rule."
        )

        return .match(rule: rule)
      }

      let count = await storage
        .coreDataManager
        .countTriggerRuleOccurrences(
          for: occurrence
        ) + 1
      let shouldFire = count <= occurrence.maxCount
      var unsavedOccurrence: TriggerRuleOccurrence?

      if shouldFire {
        unsavedOccurrence = occurrence
        return .match(rule: rule, unsavedOccurrence: unsavedOccurrence)
      } else {
        return .noMatch(source: .occurrence, experimentId: rule.experiment.id)
      }
    }

    return .noMatch(source: .expression, experimentId: rule.experiment.id)
  }
}
