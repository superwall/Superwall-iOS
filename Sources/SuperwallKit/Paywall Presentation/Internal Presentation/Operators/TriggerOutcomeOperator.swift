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
  func evaluateRules(
    configManager: ConfigManager = .shared,
    storage: Storage = .shared
  ) -> AnyPublisher<AssignmentPipelineOutput, Failure> {
    tryMap { request, debugInfo in
      if let eventData = request.presentationInfo.eventData {
        let eventOutcome = AssignmentLogic.evaluateRules(
          forEvent: eventData,
          triggers: ConfigManager.shared.triggersByEventName,
          configManager: configManager,
          storage: storage
        )
        let confirmableAssignment = eventOutcome.confirmableAssignment

        return AssignmentPipelineOutput(
          request: request,
          triggerResult: eventOutcome.triggerResult,
          confirmableAssignment: confirmableAssignment,
          debugInfo: debugInfo
        )
      } else {
        guard let paywallId = request.presentationInfo.identifier else {
          // This error will never be thrown. Just preferring this
          // to force unwrapping.
          throw PresentationPipelineError.cancelled
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
