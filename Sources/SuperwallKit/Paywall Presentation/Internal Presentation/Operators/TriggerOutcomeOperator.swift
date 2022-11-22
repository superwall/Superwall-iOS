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
  func getTriggerResult(
    configManager: ConfigManager = .shared,
    storage: Storage = .shared
  ) -> AnyPublisher<AssignmentPipelineOutput, Failure> {
    tryMap { request, debugInfo in
      if let eventData = request.presentationInfo.eventData {
        let assignmentOutcome = AssignmentLogic.getOutcome(
          forEvent: eventData,
          triggers: ConfigManager.shared.triggersByEventName,
          configManager: configManager,
          storage: storage
        )
        let confirmableAssignment = assignmentOutcome.confirmableAssignment

        return AssignmentPipelineOutput(
          request: request,
          triggerResult: assignmentOutcome.result,
          confirmableAssignment: confirmableAssignment,
          debugInfo: debugInfo
        )
      } else {
        guard let paywallId = request.presentationInfo.identifier else {
          throw PresentationPipelineError.cancelled
        }
        return AssignmentPipelineOutput(
          request: request,
          triggerResult: .paywall(experiment: .presentById(paywallId)),
          debugInfo: debugInfo
        )
      }
    }
    .eraseToAnyPublisher()
  }

  /*
  private func getTriggerOutcome(
    forResult triggerResult: TriggerResult
  ) -> TriggerResultOutcome {
    switch triggerResult {
    case .paywall(let experiment):
      let identifiers = ResponseIdentifiers(
        paywallId: experiment.variant.paywallId,
        experiment: experiment
      )
      return TriggerResultOutcome(
        info: .paywall(identifiers),
        result: triggerResult
      )
    case let .holdout(experiment):
      return TriggerResultOutcome(
        info: .holdout(experiment),
        result: triggerResult
      )
    case .noRuleMatch:
      return TriggerResultOutcome(
        info: .noRuleMatch,
        result: triggerResult
      )
    case .eventNotFound:
      return TriggerResultOutcome(
        info: .eventNotFound,
        result: triggerResult
      )
    case .error(let error):
      return TriggerResultOutcome(
        info: .error(error),
        result: triggerResult
      )
    }
  }*/
}
