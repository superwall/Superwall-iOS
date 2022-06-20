//
//  ExpressionEvaluator.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation
import JavaScriptCore

enum ExpressionEvaluator {
  static func evaluateExpression(
    fromRule rule: TriggerRule,
    eventData: EventData,
    storage: Storage = Storage.shared
  ) -> Bool {
    // Expression matches all
    if rule.expressionJs == nil && rule.expression == nil {
      return true
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

    if let postfix = getPostfix(
      forRule: rule,
      withEventData: eventData,
      storage: storage
    ) {
      let result = jsCtx.evaluateScript(script + "\n " + postfix)
      if result?.isString != nil {
        return result?.toString() == "true"
      }
    }
    return false
  }

  private static func getPostfix(
    forRule rule: TriggerRule,
    withEventData eventData: EventData,
    storage: Storage
  ) -> String? {
    var eventOccurrences: [String: [String: Any]] = [:]
    let eventNames = storage.coreDataManager.getAllEventNames()

    for eventName in eventNames {
      eventOccurrences[eventName] = OccurrenceLogic.getEventOccurrences(
        of: eventName,
        isPreemptive: false,
        storage: storage
      )
    }

    let values = JSON([
      "user": Storage.shared.userAttributes,
      "device": DeviceHelper.shared.templateDevice.toDictionary(),
      "params": eventData.parameters,
      "events": eventOccurrences
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
