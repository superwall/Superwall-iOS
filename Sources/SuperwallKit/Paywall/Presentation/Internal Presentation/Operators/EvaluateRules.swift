//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation

struct AssignmentPipelineOutput {
  let triggerResult: TriggerResult
  var confirmableAssignment: ConfirmableAssignment?
  let debugInfo: [String: Any]
}

extension Superwall {
  /// Evaluates the rules from the campaign that the event belongs to. This retrieves the trigger result and the confirmable assignment.
  ///
  /// - Parameters:
  ///   - configManager: A `ConfigManager` object used for dependency injection.
  ///   - storgate: A `Storage` object used for dependency injection.
  ///   If `true`, then it doesn't save the occurrence count of the rule.
  func evaluateRules(
    _ request: PresentationRequest,
    debugInfo: [String: Any]
  ) async throws -> AssignmentPipelineOutput {
    if let eventData = request.presentationInfo.eventData {
      let assignmentLogic = RuleLogic(
        configManager: dependencyContainer.configManager,
        storage: dependencyContainer.storage,
        factory: dependencyContainer
      )
      let eventOutcome = await assignmentLogic.evaluateRules(
        forEvent: eventData,
        triggers: dependencyContainer.configManager.triggersByEventName,
        isPreemptive: request.flags.type == .getPresentationResult
      )
      let confirmableAssignment = eventOutcome.confirmableAssignment

      return AssignmentPipelineOutput(
        triggerResult: eventOutcome.triggerResult,
        confirmableAssignment: confirmableAssignment,
        debugInfo: debugInfo
      )
    } else {
      // Called if the debugger is shown.
      guard let paywallId = request.presentationInfo.identifier else {
        // This error will never be thrown. Just preferring this
        // to force unwrapping.
        throw PresentationPipelineError.noPaywallViewController
      }
      return AssignmentPipelineOutput(
        triggerResult: .paywall(.presentById(paywallId)),
        debugInfo: debugInfo
      )
    }
  }
}
