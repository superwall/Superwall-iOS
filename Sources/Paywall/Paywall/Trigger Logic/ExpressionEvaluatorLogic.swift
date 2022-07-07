//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/07/2022.
//

import Foundation

enum ExpressionEvaluatorLogic {
  static func shouldFire(
    basedOn occurrence: TriggerRuleOccurrence?,
    ruleMatched: Bool,
    storage: Storage
  ) -> Bool {
    if ruleMatched {
      guard let occurrence = occurrence else {
        return true
      }
      let count = storage
        .coreDataManager
        .countTriggerRuleOccurrences(
          for: occurrence
        ) + 1

      let firing = count <= occurrence.maxCount

      if firing {
        storage.coreDataManager.save(triggerRuleOccurrence: occurrence)
      }

      return firing

    }
//    if let occurrence = occurrence {
//      storage.coreDataManager.save(triggerRuleOccurrence: occurrence)
//    }
    return false
  }
}
