//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/08/2024.
//
// swiftlint:disable function_body_length

import Foundation
import Superscript

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
    guard let expression = audience.expressionCel else {
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

    guard
      let resultData = evaluateWithContext(
        definition: jsonString,
        context: evaluationContext
      ).data(using: .utf8),
      let result = try? JSONDecoder().decode(EvaluationResult.self, from: resultData)
    else {
      return noMatch
    }

    switch result {
    case .success(let value):
      switch value {
      case .bool(let value) where value == true:
        return await expressionEvaluator.tryToMatchOccurrence(
          from: audience,
          expressionMatched: true
        )
      default:
        return noMatch
      }
    case .failure(let message):
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: message
      )
      return noMatch
    }
  }
}
