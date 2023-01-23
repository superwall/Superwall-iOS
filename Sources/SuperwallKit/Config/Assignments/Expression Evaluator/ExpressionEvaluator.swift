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
  private let identityManager: IdentityManager
  private let deviceHelper: DeviceHelper

  init(
    storage: Storage,
    identityManager: IdentityManager,
    deviceHelper: DeviceHelper
  ) {
    self.storage = storage
    self.identityManager = identityManager
    self.deviceHelper = deviceHelper
  }

  func evaluateExpression(
    fromRule rule: TriggerRule,
    eventData: EventData,
    isPreemptive: Bool
  ) -> Bool {
    // Expression matches all
    if rule.expressionJs == nil && rule.expression == nil {
      let shouldFire = shouldFire(
        forOccurrence: rule.occurrence,
        ruleMatched: true,
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
      withEventData: eventData
    ) else {
      return false
    }

    let result = jsCtx.evaluateScript(script + "\n " + postfix)
    if result?.isString == nil {
      return false
    }

    let isMatched = result?.toString() == "true"

    let shouldFire = shouldFire(
      forOccurrence: rule.occurrence,
      ruleMatched: isMatched,
      isPreemptive: isPreemptive
    )

    return shouldFire
  }

  private func getPostfix(
    forRule rule: TriggerRule,
    withEventData eventData: EventData
  ) -> String? {
    let values = JSON([
      "user": identityManager.userAttributes,
      "device": deviceHelper.templateDevice.toDictionary(),
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

  func shouldFire(
    forOccurrence occurrence: TriggerRuleOccurrence?,
    ruleMatched: Bool,
    isPreemptive: Bool
  ) -> Bool {
    if ruleMatched {
      guard let occurrence = occurrence else {
        Logger.debug(
          logLevel: .debug,
          scope: .paywallPresentation,
          message: "No occurrence parameter found for trigger rule."
        )
        return true
      }
      let count = storage
        .coreDataManager
        .countTriggerRuleOccurrences(
          for: occurrence
        ) + 1
      let shouldFire = count <= occurrence.maxCount

      if shouldFire,
        !isPreemptive {
        storage.coreDataManager.save(triggerRuleOccurrence: occurrence)
      }

      return shouldFire
    }

    return false
  }
}
