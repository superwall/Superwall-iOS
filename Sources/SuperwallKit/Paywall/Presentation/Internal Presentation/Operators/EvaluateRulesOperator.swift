//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

struct AssignmentPipelineOutput {
  let request: PresentationRequest
  let triggerResult: TriggerResult
  var confirmableAssignment: ConfirmableAssignment?
  let debugInfo: DebugInfo
}

extension AnyPublisher where Output == (PresentationRequest, DebugInfo), Failure == Error {
  /// Evaluates the rules from the campaign that the event belongs to. This retrieves the trigger result and the confirmable assignment.
  ///
  /// - Parameters:
  ///   - configManager: A `ConfigManager` object used for dependency injection.
  ///   - storgate: A `Storage` object used for dependency injection.
  ///   If `true`, then it doesn't save the occurrence count of the rule.
  func evaluateRules() -> AnyPublisher<AssignmentPipelineOutput, Failure> {
    asyncMap { request, debugInfo in
      if let eventData = request.presentationInfo.eventData {
        let assignmentLogic = RuleLogic(
          configManager: request.dependencyContainer.configManager,
          storage: request.dependencyContainer.storage,
          factory: request.dependencyContainer
        )
        let eventOutcome = await assignmentLogic.evaluateRules(
          forEvent: eventData,
          triggers: request.dependencyContainer.configManager.triggersByEventName,
          isPreemptive: request.flags.type == .getPresentationResult
        )
        let confirmableAssignment = eventOutcome.confirmableAssignment

        return AssignmentPipelineOutput(
          request: request,
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
          request: request,
          triggerResult: .paywall(.presentById(paywallId)),
          debugInfo: debugInfo
        )
      }
    }
    .eraseToAnyPublisher()
  }
}
