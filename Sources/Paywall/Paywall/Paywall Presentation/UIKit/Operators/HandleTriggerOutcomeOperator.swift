//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

typealias TriggerOutcomeResponsePipelineData = (
  request: PaywallPresentationRequest,
  triggerOutcome: TriggerResultOutcome,
  debugInfo: DebugInfo,
  responseIdentifiers: ResponseIdentifiers
)

extension AnyPublisher where Output == TriggerOutcomePipelineData, Failure == Error {
  func handleTriggerOutcome(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    configManager: ConfigManager = .shared
  ) -> AnyPublisher<TriggerOutcomeResponsePipelineData, Error> {
    self
      .tryMap { request, triggerOutcome, debugInfo in
        switch triggerOutcome.info {
        case .paywall(let responseIdentifiers):
          return (request, triggerOutcome, debugInfo, responseIdentifiers)
        case .holdout(let experiment):
          SessionEventsManager.shared.triggerSession.activateSession(
            for: request.presentationInfo,
            on: request.presentingViewController,
            triggerResult: triggerOutcome.result
          )
          paywallStatePublisher.send(.skipped(.holdout(experiment)))
        case .noRuleMatch:
          SessionEventsManager.shared.triggerSession.activateSession(
            for: request.presentationInfo,
            on: request.presentingViewController,
            triggerResult: triggerOutcome.result
          )
          paywallStatePublisher.send(.skipped(.noRuleMatch))
        case .triggerNotFound:
          paywallStatePublisher.send(.skipped(.triggerNotFound))
        case let .error(error):
          Logger.debug(
            logLevel: .error,
            scope: .paywallPresentation,
            message: "Error Getting Paywall View Controller",
            info: debugInfo,
            error: error
          )
          paywallStatePublisher.send(.skipped(.error(error)))
        }

        throw PresentationPipelineError.cancelled
      }
      .eraseToAnyPublisher()
  }
}
