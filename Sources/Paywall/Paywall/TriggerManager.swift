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
    case UnknownEvent
    // experimentId, variantId
    case Holdout(String, String)
    // None of the rules match
    case NoRuleMatch
    // Present v1
    case PresentV1
    // experimentId, variantId, paywallIdentifier
    case PresentIdentifier(String, String, String)
}


class TriggerManager {
    
    internal static let shared = TriggerManager();
    
    internal func handleEvent(eventName: String, eventData: EventData?) -> HandleEventResult {
        // If we have the config response, all valid triggers should be in reponse
        
        // See if this is a v2 trigger
        if let triggerV2: TriggerV2 = Store.shared.v2Triggers[eventName] {
            if let rule = self.resolveAndAssign(v2Trigger: triggerV2, eventData: eventData) {
                switch(rule.variant) {
                case .Holdout(let holdout):
                    return HandleEventResult.Holdout(rule.experimentId, holdout.variantId)
                case .Treatment(let treatment):
                    return HandleEventResult.PresentIdentifier(rule.experimentId, treatment.variantId, treatment.paywallIdentifier)
                }
            } else {
                return HandleEventResult.NoRuleMatch
            }
        } else {
            // Check for v1 triggers
            if (!Store.shared.triggers.contains(eventName)){
                return HandleEventResult.UnknownEvent
            }
            return HandleEventResult.PresentV1
        }
    }
    
    
    private func resolveAndAssign(v2Trigger: TriggerV2, eventData: EventData?) -> TriggerRule? {
        for  rule in v2Trigger.rules {
            if ExpressionEvaluator.evaluateExpression(expression: rule.expression, eventData: eventData) {
                // We've found the correct one
                if (!rule.assigned) {
                    // Call confirm assignment
                    // TODO: Actually update cache so we don't call this every time. However, this
                    // is idempotent so we can call this as many times as we like. Once config is refreshed
                    // this will be false and we'll stop updating it.
                    Network.shared.confirmAssignments(confirmAssignments: ConfirmAssignments(assignments: [Assignment(experimentId: rule.experimentId, variantId: rule.variantId)]), completion: nil)
                    
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

internal struct ExpressionEvaluator  {
    
    
    public static func evaluateExpression(expression: String?, eventData: EventData?) -> Bool {
        // Expression matches all
        if ((expression == nil)) {
            return true
        }
        
        
        let jsCtx = JSContext.init()!
        jsCtx.exceptionHandler = { (ctx: JSContext!, value: JSValue!) in
            // type of String
            let stacktrace = value.objectForKeyedSubscript("stack").toString()
            // type of Number
            let lineNumber = value.objectForKeyedSubscript("line")
            // type of Number
            let column = value.objectForKeyedSubscript("column")
            let moreInfo = "in method \(String(describing: stacktrace))Line number in file: \(String(describing: lineNumber)), column: \(String(describing: column))"
            Logger.debug(logLevel: .error, scope: .events, message: "JS ERROR: \(String(describing: value)) \(moreInfo)", info: nil, error: nil)
        }
        
        let parameters = ExpressionEvaluatorParams(expression: expression!, values:  JSON([
            "user": Store.shared.userAttributes,
            "device": DeviceHelper.shared.templateDevice.toDictionary(),
            "params": eventData?.parameters ?? [:],
        ]))
        if let base64String = parameters.toBase64Input() {
            let postfix = "\n SuperwallSDKJS.evaluate64('\(base64String)');"
            let result =  jsCtx.evaluateScript(script + "\n " + postfix)
            if ((result?.isString) != nil) {
                return result?.toString() == "true"
            }
        }
        return false
       
    }
}
