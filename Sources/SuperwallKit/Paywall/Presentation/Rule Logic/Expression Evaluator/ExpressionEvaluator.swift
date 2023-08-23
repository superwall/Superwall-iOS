//
//  ExpressionEvaluator.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation
import JavaScriptCore

struct ExpressionEvaluator {
  private let storage: Storage
  private unowned let factory: RuleAttributesFactory

  struct TriggerFireOutcome {
    let shouldFire: Bool
    var unsavedOccurrence: TriggerRuleOccurrence?
  }

  init(
    storage: Storage,
    factory: RuleAttributesFactory
  ) {
    self.storage = storage
    self.factory = factory
  }

  func evaluateExpression(
    fromRule rule: TriggerRule,
    eventData: EventData
  ) async -> TriggerFireOutcome {
    // Expression matches all
    if rule.expressionJs == nil && rule.expression == nil {
      let shouldFire = await shouldFire(
        forOccurrence: rule.occurrence,
        ruleMatched: true
      )
      return shouldFire
    }

    guard let jsCtx = JSContext() else {
      return TriggerFireOutcome(shouldFire: false)
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

    guard let postfix = await getPostfix(
      forRule: rule,
      withEventData: eventData
    ) else {
      return TriggerFireOutcome(shouldFire: false)
    }

    let result = jsCtx.evaluateScript(script + "\n " + postfix)
    if result?.isString == nil {
      return TriggerFireOutcome(shouldFire: false)
    }

    let isMatched = result?.toString() == "true"

    let shouldFire = await shouldFire(
      forOccurrence: rule.occurrence,
      ruleMatched: isMatched
    )

    return shouldFire
  }

  private func getPostfix(
    forRule rule: TriggerRule,
    withEventData eventData: EventData
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

  func shouldFire(
    forOccurrence occurrence: TriggerRuleOccurrence?,
    ruleMatched: Bool
  ) async -> TriggerFireOutcome {
    if ruleMatched {
      guard let occurrence = occurrence else {
        Logger.debug(
          logLevel: .debug,
          scope: .paywallPresentation,
          message: "No occurrence parameter found for trigger rule."
        )

        return TriggerFireOutcome(shouldFire: true)
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
      }

      return TriggerFireOutcome(
        shouldFire: shouldFire,
        unsavedOccurrence: unsavedOccurrence
      )
    }

    return TriggerFireOutcome(shouldFire: false)
  }
}
