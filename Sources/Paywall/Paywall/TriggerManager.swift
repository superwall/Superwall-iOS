//
//  TriggerManager.swift
//  Superwall
//
//  Created by Brian Anglin on 2/21/22.
//

import Foundation
import JavaScriptCore
import UIKit

enum HandleEventResult {
  case unknownEvent
  // experimentId, variantId
  case holdout(String, String)
  // None of the rules match
  case noRuleMatch
  // Present v1
  case presentV1
  // experimentId, variantId, paywallIdentifier
  case presentIdentifier(String, String, String)
}

final class TriggerManager {
  static let shared = TriggerManager()

  func handleEvent(
    eventName: String,
    eventData: EventData?
  ) -> HandleEventResult {
    // If we have the config response, all valid triggers should be in reponse

    // See if this is a v2 trigger
    if let triggerV2: TriggerV2 = Store.shared.v2Triggers[eventName] {
      if let rule = self.resolveAndAssign(v2Trigger: triggerV2, eventData: eventData) {
        switch rule.variant {
        case .holdout(let holdout):
          return HandleEventResult.holdout(rule.experimentId, holdout.variantId)
        case .treatment(let treatment):
          return HandleEventResult.presentIdentifier(
            rule.experimentId,
            treatment.variantId,
            treatment.paywallIdentifier
          )
        }
      } else {
        return HandleEventResult.noRuleMatch
      }
    } else {
      // Check for v1 triggers
      if !Store.shared.triggers.contains(eventName) {
        return HandleEventResult.unknownEvent
      }
      return HandleEventResult.presentV1
    }
  }

  private func resolveAndAssign(
    v2Trigger: TriggerV2,
    eventData: EventData?
  ) -> TriggerRule? {
    for rule in v2Trigger.rules {
      if ExpressionEvaluator.evaluateExpression(expression: rule.expression, eventData: eventData) {
        // We've found the correct one
        if !rule.assigned {
          // Call confirm assignment
          // TODO: Actually update cache so we don't call this every time. However, this
          // is idempotent so we can call this as many times as we like. Once config is refreshed
          // this will be false and we'll stop updating it.
          Network.shared.confirmAssignments(
            confirmAssignments:
              ConfirmAssignments(assignments: [Assignment(experimentId: rule.experimentId, variantId: rule.variantId)]),
            completion: nil
          )
        }
        return rule
      }
    }
    return nil
  }
}


struct ExpressionEvaluatorParams: Codable {
  var expression: String
  var values: JSON

  func toBase64Input() -> String? {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(self) {
      return data.base64EncodedString()
    }
    return nil
  }
}

enum ExpressionEvaluator {
  static func evaluateExpression(
    expression: String?,
    eventData: EventData?
  ) -> Bool {
    // Expression matches all
    if expression == nil {
      return true
    }

    // swiftlint:disable:next force_unwrapping
    let jsCtx = JSContext.init()!
    jsCtx.exceptionHandler = { (_, value: JSValue?) in
      guard let value = value else {
        return
      }
      // type of String
      let stacktrace = value.objectForKeyedSubscript("stack").toString()
      // type of Number
      let lineNumber = value.objectForKeyedSubscript("line")
      // type of Number
      let column = value.objectForKeyedSubscript("column")
      // swiftlint:disable:next line_length
      let moreInfo = "in method \(String(describing: stacktrace))Line number in file: \(String(describing: lineNumber)), column: \(String(describing: column))"
      Logger.debug(
        logLevel: .error,
        scope: .events,
        message: "JS ERROR: \(String(describing: value)) \(moreInfo)",
        info: nil,
        error: nil
      )
    }

    let parameters = ExpressionEvaluatorParams(
      // swiftlint:disable:next force_unwrapping
      expression: expression!,
      values: JSON([
        "user": Store.shared.userAttributes,
        "device": DeviceHelper.shared.templateDevice.toDictionary(),
        "params": eventData?.parameters ?? [:]
      ])
    )

    if let base64String = parameters.toBase64Input() {
      let postfix = "\n SuperwallSDKJS.evaluate64('\(base64String)');"
      let result = jsCtx.evaluateScript(script + "\n " + postfix)
      if result?.isString != nil {
        return result?.toString() == "true"
      }
    }
    return false
  }
}
