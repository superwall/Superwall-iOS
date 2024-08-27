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
  private let expressionLogic: ExpressionLogic

  init(
    storage: Storage,
    factory: RuleAttributesFactory
  ) {
    self.storage = storage
    self.factory = factory
    self.expressionLogic = ExpressionLogic(storage: storage)
  }

  func evaluateExpression(
    fromRule rule: TriggerRule,
    eventData: EventData?
  ) async -> TriggerRuleOutcome {
    let attributes = await factory.makeRuleAttributes(
      forEvent: eventData,
      withComputedProperties: rule.computedPropertyRequests
    )

    let passableValue = toPassableValue(from: attributes)
    var variablesMap: [String: PassableValue] = [:]
    if case let PassableValue.map(dictionary) = passableValue {
      variablesMap = dictionary
    }

    let executionContext = ExecutionContext(
      variables: PassableMap(map: variablesMap),
      expression: rule.expression ?? "",
      platform: [:]
    )

    let noMatch = TriggerRuleOutcome.noMatch(
      source: .expression,
      experimentId: rule.experiment.id
    )

    guard
      let jsonData = try? JSONEncoder().encode(executionContext),
      let jsonString = String(data: jsonData, encoding: .utf8)
    else {
      return noMatch
    }

    let result = evaluateWithContext(
      definition: jsonString,
      context: HostContextImpl()
    )

    if result == "true" {
      return await expressionLogic.tryToMatchOccurrence(
        from: rule, expressionMatched: true
      )
    } else {
      return noMatch
    }
  }
}

private class HostContextImpl: HostContext {
  let storage: Storage

  init(storage: Storage) {
    self.storage = storage
  }

  func computedProperty(name: String, args: String) async -> String {
//    if let value = await storage.coreDataManager.getComputedPropertySinceEvent(
//      EventData(name: name, parameters: [:], createdAt: Date()),
//      request: computedPropertyRequest
//    ) {
//      output[computedPropertyRequest.type.prefix + computedPropertyRequest.eventName] = value
//    }
  }
}


extension Dictionary where Key == String, Value == Any {
  func toPassableValue() -> PassableValue {
    let passableMap = self.mapValues { SuperwallKit.toPassableValue(from: $0) }
    return PassableValue.map(passableMap)
  }
}

func toPassableValue(from anyValue: Any) -> PassableValue {
  switch anyValue {
  case let value as Int:
    return .int(value)
  case let value as UInt64:
    return .uint(value)
  case let value as Double:
    return .float(value)
  case let value as String:
    return .string(value)
  case let value as Data:
    return .bytes(value)
  case let value as Bool:
    return .bool(value)
  case let value as [Any]:
    return .list(value.map { toPassableValue(from: $0) })
  case let value as [AnyHashable: Any]:
    let stringKeyMap = value.compactMap { (key, value) -> (String, Any)? in
      if let key = key as? String {
        return (key, value)
      }
      return nil
    }
    let passableMap = stringKeyMap.reduce(into: [:]) { result, pair in
      result[pair.0] = toPassableValue(from: pair.1)
    }

    return .map(passableMap)
  case let value as PassableValue:
    return value
  default:
    fatalError("Unsupported type: \(anyValue)")
  }
}
