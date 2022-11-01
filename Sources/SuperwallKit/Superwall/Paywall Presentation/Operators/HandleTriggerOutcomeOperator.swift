//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

struct TriggerOutcomeResponsePipelineOutput {
  let request: PresentationRequest
  let triggerOutcome: TriggerResultOutcome
  let debugInfo: DebugInfo
  let responseIdentifiers: ResponseIdentifiers
}

extension AnyPublisher where Output == TriggerOutcomePipelineOutput, Failure == Error {
  func handleTriggerOutcome(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    configManager: ConfigManager = .shared
  ) -> AnyPublisher<TriggerOutcomeResponsePipelineOutput, Error> {
    asyncMap { input in
      switch input.triggerOutcome.info {
      case .paywall(let responseIdentifiers):
        return TriggerOutcomeResponsePipelineOutput(
          request: input.request,
          triggerOutcome: input.triggerOutcome,
          debugInfo: input.debugInfo,
          responseIdentifiers: responseIdentifiers
        )
      case .holdout(let experiment):
        await SessionEventsManager.shared.triggerSession.activateSession(
          for: input.request.presentationInfo,
          on: input.request.presentingViewController,
          triggerResult: input.triggerOutcome.result
        )
        paywallStatePublisher.send(.skipped(.holdout(experiment)))
      case .noRuleMatch:
        await SessionEventsManager.shared.triggerSession.activateSession(
          for: input.request.presentationInfo,
          on: input.request.presentingViewController,
          triggerResult: input.triggerOutcome.result
        )
        paywallStatePublisher.send(.skipped(.noRuleMatch))
      case .triggerNotFound:
        paywallStatePublisher.send(.skipped(.triggerNotFound))
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
