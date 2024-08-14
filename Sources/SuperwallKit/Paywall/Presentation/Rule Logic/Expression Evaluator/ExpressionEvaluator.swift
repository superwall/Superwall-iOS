//
//  ExpressionEvaluator.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation
import JavaScriptCore
import SuperCEL

protocol ExpressionEvaluating {
  func evaluateExpression(
    fromRule rule: TriggerRule,
    eventData: EventData?
  ) async -> TriggerRuleOutcome
}

struct ExpressionEvaluator: ExpressionEvaluating {
  private let storage: Storage
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
    // Expression matches all
    if rule.expressionJs == nil && rule.expression == nil {
      let ruleMatched = await expressionLogic.tryToMatchOccurrence(
        from: rule,
        expressionMatched: true
      )
      return ruleMatched
    }

    guard let jsCtx = JSContext() else {
      return .noMatch(source: .expression, experimentId: rule.experiment.id)
    }
    jsCtx.exceptionHandler = { (_, value: JSValue?) in
      guard let value = value else {
        return
      }
      let stackTraceString = value
        .objectForKeyedSubscript("stack")
        .toString()
      let lineNumber = value.objectForKeyedSubscript("line")
      let columnNumber = value.objectForKeyedSubscript("column")

      // swiftlint:disable:next line_length
      let moreInfo = "In method \(String(describing: stackTraceString)), Line number in file: \(String(describing: lineNumber)), column: \(String(describing: columnNumber))"
      Logger.debug(
        logLevel: .error,
        scope: .events,
        message: "JS ERROR: \(String(describing: value)) \(moreInfo)",
        info: nil,
        error: nil
      )
    }

    guard let base64Params = await getBase64Params(
      from: rule,
      withEventData: eventData
    ) else {
      return .noMatch(source: .expression, experimentId: rule.experiment.id)
    }

    let result = jsCtx.evaluateScript(script + "\n " + base64Params)
    if result?.isString == nil {
      return .noMatch(source: .expression, experimentId: rule.experiment.id)
    }

    let expressionMatched = result?.toString() == "true"

    let ruleMatched = await expressionLogic.tryToMatchOccurrence(
      from: rule,
      expressionMatched: expressionMatched
    )

    return ruleMatched
  }

  private func getBase64Params(
    from rule: TriggerRule,
    withEventData eventData: EventData?
  ) async -> String? {
    let attributes = await factory.makeRuleAttributes(
      forEvent: eventData,
      withComputedProperties: rule.computedPropertyRequests
    )
    let jsonAttributes = JSON(attributes)

    if let expressionJs = rule.expressionJs {
      if let base64Params = JsExpressionEvaluatorParams(
        expressionJs: expressionJs,
        values: jsonAttributes
      ).toBase64Input() {
        let postfix = "\n SuperwallSDKJS.evaluateJS64('\(base64Params)');"
        return postfix
      }
      return nil
    } else if let expression = rule.expression {
      if let base64Params = LiquidExpressionEvaluatorParams(
        expression: expression,
        values: jsonAttributes
      ).toBase64Input() {
        let postfix = "\n SuperwallSDKJS.evaluate64('\(base64Params)');"
        return postfix
      }
      return nil
    }
    return nil
  }
}
