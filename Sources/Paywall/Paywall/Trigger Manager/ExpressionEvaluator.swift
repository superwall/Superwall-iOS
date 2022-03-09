//
//  ExpressionEvaluator.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation
import JavaScriptCore

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
    eventData: EventData
  ) -> Bool {
    // Expression matches all
    guard let expression = expression else {
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

    let parameters = ExpressionEvaluatorParams(
      expression: expression,
      values: JSON([
        "user": Storage.shared.userAttributes,
        "device": DeviceHelper.shared.templateDevice.toDictionary(),
        "params": eventData.parameters
      ])
    )

    if let base64String = parameters.toBase64Input() {
      let postfix = "\n SuperwallSDKJS.evaluate64('\(base64String)');"
      let result = jsCtx.evaluateScript(script + "\n " + postfix)
      if result?.isString != nil {
        print("the result is!", result?.toString())
        return result?.toString() == "true"
      }
    }
    return false
  }
}
