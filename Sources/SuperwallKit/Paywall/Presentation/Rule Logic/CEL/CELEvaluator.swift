//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/08/2024.
//

import Foundation
import SuperCEL

struct CELEvaluator: ExpressionEvaluating {
  private unowned let storage: Storage
  private unowned let factory: RuleAttributesFactory
  private let expressionEvaluator: ExpressionEvaluator
  private let evaluationContext: EvaluationContext

  init(
    storage: Storage,
    factory: RuleAttributesFactory
  ) {
    self.storage = storage
    self.evaluationContext = EvaluationContext(storage: storage)
    self.factory = factory
    self.expressionEvaluator = ExpressionEvaluator(
      storage: storage,
      factory: factory
    )
  }

  func evaluateExpression(
    fromRule audience: TriggerRule,
    eventData placementData: EventData?
  ) async -> TriggerRuleOutcome {
    guard let expression = audience.expression else {
      let audienceMatched = await expressionEvaluator.tryToMatchOccurrence(
        from: audience,
        expressionMatched: true
      )
      return audienceMatched
    }
    let attributes = await factory.makeRuleAttributes(
      forEvent: placementData,
      withComputedProperties: audience.computedPropertyRequests
    )

    var computedProperties: [String: [PassableValue]] = [:]
    for computedPropertyRequest in audience.computedPropertyRequests {
      let description = computedPropertyRequest.type.description
      let placementName = computedPropertyRequest.eventName
      computedProperties[description] = [toPassableValue(from: placementName)]
    }

    let attributesPassableValue = toPassableValue(from: attributes)
    var variablesMap: [String: PassableValue] = [:]
    if case let PassableValue.map(dictionary) = attributesPassableValue {
      variablesMap = dictionary
    }
    let executionContext = ExecutionContext(
      variables: PassableMap(map: variablesMap),
      computed: computedProperties,
      device: [:],
      expression: expression
    )

    let noMatch = TriggerRuleOutcome.noMatch(
      source: .expression,
      experimentId: audience.experiment.id
    )

    guard
      let jsonData = try? JSONEncoder().encode(executionContext),
      let jsonString = String(data: jsonData, encoding: .utf8)
    else {
      return noMatch
    }

    let result = evaluateWithContext(
      definition: jsonString,
      context: evaluationContext
    )

    if result == "true" {
      return await expressionEvaluator.tryToMatchOccurrence(
        from: audience,
        expressionMatched: true
      )
    } else {
      return noMatch
    }
  }
}
