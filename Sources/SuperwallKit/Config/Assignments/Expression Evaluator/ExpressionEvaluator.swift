//
//  ExpressionEvaluator.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation
import JavaScriptCore

enum ExpressionEvaluator {
  static func evaluateExpression(
    fromRule rule: TriggerRule,
    eventData: EventData,
    storage: Storage = Storage.shared,
    isPreemptive: Bool
  ) -> Bool {
    // Expression matches all
    if rule.expressionJs == nil && rule.expression == nil {
      let shouldFire = ExpressionEvaluatorLogic.shouldFire(
        forOccurrence: rule.occurrence,
        ruleMatched: true,
        storage: storage,
        isPreemptive: isPreemptive
      )
      return shouldFire
    }

    // swiftlint:disable:next force_unwrapping
    let jsCtx = JSContext()!
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

    guard let postfix = getPostfix(
      forRule: rule,
      withEventData: eventData,
      storage: storage
    ) else {
      return false
    }

    let result = jsCtx.evaluateScript(script + "\n " + postfix)
    if result?.isString == nil {
      return false
    }

    let isMatched = result?.toString() == "true"

    let shouldFire = ExpressionEvaluatorLogic.shouldFire(
      forOccurrence: rule.occurrence,
      ruleMatched: isMatched,
      storage: storage,
      isPreemptive: isPreemptive
    )

    return shouldFire
  }

  private static func getPostfix(
    forRule rule: TriggerRule,
    withEventData eventData: EventData,
    storage: Storage
  ) -> String? {
    let values = JSON([
      "user": IdentityManager.shared.userAttributes,
      "device": DeviceHelper.shared.templateDevice.toDictionary(),
      "params": eventData.parameters
    ])

    if let expressionJs = rule.expressionJs {
      if let base64Params = JavascriptExpressionEvaluatorParams(
        expressionJs: expressionJs,
        values: values
      ).toBase64Input() {
        let postfix = "\n SuperwallSDKJS.evaluateJS64('\(base64Params)');"
        return postfix
      }
      return nil
    } else if let expression = rule.expression {
      if let base64Params = LiquidExpressionEvaluatorParams(
        expression: expression,
        values: values
      ).toBase64Input() {
        let postfix = "\n SuperwallSDKJS.evaluate64('\(base64Params)');"
        return postfix
      }
      return nil
    }
    return nil
  }
}
