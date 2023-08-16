//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation

extension Superwall {
  /// Evaluates the rules from the campaign that the event belongs to
  ///
  /// - Parameter request: The presentation request
  /// - Returns: An `EvaluateRulesOutput` object containing the trigger result and confirmable assignment.
  func evaluateRules(
    from request: PresentationRequest
  ) async throws -> RuleEvaluationOutcome {
    if let eventData = request.presentationInfo.eventData {
      let ruleLogic = RuleLogic(
        configManager: dependencyContainer.configManager,
        storage: dependencyContainer.storage,
        factory: dependencyContainer
      )
      return await ruleLogic.evaluateRules(
        forEvent: eventData,
        triggers: dependencyContainer.configManager.triggersByEventName,
        isPreemptive: request.flags.type == .getPresentationResult
      )
    } else {
      // Called if the debugger is shown.
      guard let paywallId = request.presentationInfo.identifier else {
        // This error will never be thrown. Just preferring this
        // to force unwrapping.
        throw PresentationPipelineError.noPaywallViewController
      }
      return RuleEvaluationOutcome(
        triggerResult: .paywall(.presentById(paywallId))
      )
    }
  }
}
