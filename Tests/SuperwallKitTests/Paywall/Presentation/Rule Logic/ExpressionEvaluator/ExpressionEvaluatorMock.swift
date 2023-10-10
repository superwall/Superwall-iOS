//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/10/2023.
//
// swiftlint:disable all

import Foundation
@testable import SuperwallKit

struct ExpressionEvaluatorMock: ExpressionEvaluating {
  let outcome: TriggerRuleOutcome

  func evaluateExpression(fromRule rule: TriggerRule, eventData: EventData?) async -> TriggerRuleOutcome {
    return outcome
  }
}
