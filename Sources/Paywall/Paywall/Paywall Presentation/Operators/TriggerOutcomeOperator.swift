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
    case triggerNotFound
    case noRuleMatch
    case error(NSError)
  }
  let info: Info
  var result: TriggerResult?
}

typealias AssignmentPipelineData = (
  request: PaywallPresentationRequest,
  triggerOutcome: TriggerResultOutcome,
  confirmableAssignment: ConfirmableAssignment?,
  debugInfo: DebugInfo
)

extension AnyPublisher where Output == (PaywallPresentationRequest, DebugInfo), Failure == Error {
  func getTriggerOutcome(
    configManager: ConfigManager = .shared,
    storage: Storage = .shared
  ) -> AnyPublisher<AssignmentPipelineData, Failure> {
    self
      .map { request, debugInfo in
        if let eventData = request.presentationInfo.eventData {
          let assignmentOutcome = AssignmentLogic.getOutcome(
            forEvent: eventData,
            triggers: ConfigManager.shared.triggers,
            configManager: configManager,
            storage: storage
          )

          let confirmableAssignment = assignmentOutcome.confirmableAssignment

          let triggerOutcome = getTriggerOutcome(forResult: assignmentOutcome.result)
          return (request, triggerOutcome, confirmableAssignment, debugInfo)
        } else {
          let identifiers = ResponseIdentifiers(paywallId: request.presentationInfo.identifier)
          let triggerOutcome = TriggerResultOutcome(
            info: .paywall(identifiers)
          )
          return (request, triggerOutcome, nil, debugInfo)
        }
      }
      .eraseToAnyPublisher()
  }

  // TODO: MOVE THIS TO A LOGIC HANDLER
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
    case .triggerNotFound:
      return TriggerResultOutcome(
        info: .triggerNotFound,
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
