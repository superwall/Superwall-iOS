//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

struct TriggerResultOutcome {
  enum Info {
    case paywall(ResponseIdentifiers)
    case holdout(Experiment)
    case eventNotFound
    case noRuleMatch
    case error(NSError)
  }
  let info: Info
  var result: TriggerResult?
}

struct AssignmentPipelineOutput {
  let request: PresentationRequest
  let triggerOutcome: TriggerResultOutcome
  var confirmableAssignment: ConfirmableAssignment?
  let debugInfo: DebugInfo
}

extension AnyPublisher where Output == (PresentationRequest, DebugInfo), Failure == Error {
  func getTriggerOutcome(
    configManager: ConfigManager = .shared,
    storage: Storage = .shared
  ) -> AnyPublisher<AssignmentPipelineOutput, Failure> {
    map { request, debugInfo in
      if let eventData = request.presentationInfo.eventData {
        let assignmentOutcome = AssignmentLogic.getOutcome(
          forEvent: eventData,
          triggers: ConfigManager.shared.triggersByEventName,
          configManager: configManager,
          storage: storage
        )
        let confirmableAssignment = assignmentOutcome.confirmableAssignment
        let triggerOutcome = getTriggerOutcome(forResult: assignmentOutcome.result)

        return AssignmentPipelineOutput(
          request: request,
          triggerOutcome: triggerOutcome,
          confirmableAssignment: confirmableAssignment,
          debugInfo: debugInfo
        )
      } else {
        let identifiers = ResponseIdentifiers(paywallId: request.presentationInfo.identifier)
        let triggerOutcome = TriggerResultOutcome(
          info: .paywall(identifiers)
        )

        return AssignmentPipelineOutput(
          request: request,
          triggerOutcome: triggerOutcome,
          debugInfo: debugInfo
        )
      }
    }
    .eraseToAnyPublisher()
  }

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
  }
}
