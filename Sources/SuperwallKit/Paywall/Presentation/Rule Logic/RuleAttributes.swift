//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/01/2023.
//

import Foundation

struct RuleAttributes {
  let user: [String: Any]
  var device: [String: Any]

  mutating func addDaysSinceLastAttributes(
    given rule: TriggerRule,
    coreDataManager: CoreDataManager
  ) async {
    let expression = rule.expressionJs ?? rule.expression ?? ""
    let eventPrefix = "daysSinceLast_"
    let pattern = eventPrefix + "([a-zA-Z0-9_]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return
    }

    var eventNames: [String] = []
    let range = NSRange(expression.startIndex..<expression.endIndex, in: expression)
    regex.enumerateMatches(in: expression, range: range) { result, _, _ in
      if let result = result,
        let matchRange = Range(result.range(at: 1), in: expression) {
        let name = String(expression[matchRange])
        eventNames.append(name)
      }
    }

    for name in eventNames {
      if let daysSinceLastEvent = await coreDataManager.getDaysSinceLastEvent(name: name) {
        let attribute = eventPrefix + name
        device[attribute] = daysSinceLastEvent
      }
    }
  }
}
