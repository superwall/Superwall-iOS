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
  ///   - isPreemptive: A boolean that determines whether the rules are being evaluated before actually tracking an event.
  ///   If `true`, then it doesn't save the occurrence count of the rule.
  func evaluateRules(
    configManager: ConfigManager = .shared,
    storage: Storage = .shared,
    isPreemptive: Bool = false
  ) -> AnyPublisher<AssignmentPipelineOutput, Failure> {
    tryMap { request, debugInfo in
      if let eventData = request.presentationInfo.eventData {
        let eventOutcome = AssignmentLogic.evaluateRules(
          forEvent: eventData,
          triggers: ConfigManager.shared.triggersByEventName,
          configManager: configManager,
          storage: storage,
          isPreemptive: isPreemptive
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
