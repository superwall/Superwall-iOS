//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

struct TriggerResultResponsePipelineOutput {
  let request: PresentationRequest
  let triggerResult: TriggerResult
  let debugInfo: DebugInfo
  let experiment: Experiment
}

extension AnyPublisher where Output == TriggerResultPipelineOutput, Failure == Error {
  func handleTriggerResult(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<TriggerResultResponsePipelineOutput, Error> {
    asyncMap { input in
      switch input.triggerResult {
      case .paywall(let experiment):
        return TriggerResultResponsePipelineOutput(
          request: input.request,
          triggerResult: input.triggerResult,
          debugInfo: input.debugInfo,
          experiment: experiment
        )
      case .holdout(let experiment):
        await SessionEventsManager.shared.triggerSession.activateSession(
          for: input.request.presentationInfo,
          on: input.request.presentingViewController,
          triggerResult: input.triggerResult
        )
        paywallStatePublisher.send(.skipped(.holdout(experiment)))
      case .noRuleMatch:
        await SessionEventsManager.shared.triggerSession.activateSession(
          for: input.request.presentationInfo,
          on: input.request.presentingViewController,
          triggerResult: input.triggerResult
        )
        paywallStatePublisher.send(.skipped(.noRuleMatch))
      case .eventNotFound:
        paywallStatePublisher.send(.skipped(.eventNotFound))
      case let .error(error):
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Error Getting Paywall View Controller",
          info: input.debugInfo,
          error: error
        )
        paywallStatePublisher.send(.skipped(.error(error)))
      }

      paywallStatePublisher.send(completion: .finished)
      throw PresentationPipelineError.cancelled
    }
    .eraseToAnyPublisher()
  }
}
