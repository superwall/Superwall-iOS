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
  private unowned let factory: AudienceFilterAttributesFactory
  private let expressionLogic: ExpressionLogic
  private let evaluationContext: EvaluationContext

  init(
    storage: Storage,
    factory: AudienceFilterAttributesFactory
  ) {
    self.storage = storage
    self.evaluationContext = EvaluationContext(storage: storage)
    self.factory = factory
    self.expressionLogic = ExpressionLogic(storage: storage)
  }

  func evaluateExpression(
    fromAudienceFilter audience: TriggerRule,
    placementData: PlacementData?
  ) async -> TriggerAudienceOutcome {
    let attributes = await factory.makeAudienceFilterAttributes(
      forPlacement: placementData,
      withComputedProperties: audience.computedPropertyRequests
    )

    let passableValue = toPassableValue(from: attributes)
    var variablesMap: [String: PassableValue] = [:]
    if case let PassableValue.map(dictionary) = passableValue {
      variablesMap = dictionary
    }

    let executionContext = ExecutionContext(
      variables: PassableMap(map: variablesMap),
      expression: audience.expression ?? "",
      platform: [:]
    )

    let noMatch = TriggerAudienceOutcome.noMatch(
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
      return await expressionLogic.tryToMatchOccurrence(
        from: audience,
        expressionMatched: true
      )
    } else {
      return noMatch
    }
  }
}
