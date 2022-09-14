//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/07/2022.
//

import Foundation

enum ExpressionEvaluatorLogic {
  static func shouldFire(
    forOccurrence occurrence: TriggerRuleOccurrence?,
    ruleMatched: Bool,
    storage: Storage
  ) -> Bool {
    if ruleMatched {
      guard let occurrence else {
        Logger.debug(
          logLevel: .debug,
          scope: .paywallPresentation,
          message: "No occurrence parameter found for trigger rule."
        )
        return true
      }
      let count = storage
        .coreDataManager
        .countTriggerRuleOccurrences(
          for: occurrence
        ) + 1
      let shouldFire = count <= occurrence.maxCount

      if shouldFire {
        storage.coreDataManager.save(triggerRuleOccurrence: occurrence)
      }

      return shouldFire
    }

    return false
  }
}
