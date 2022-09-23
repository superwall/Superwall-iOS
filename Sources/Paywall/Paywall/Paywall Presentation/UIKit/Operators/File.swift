//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension PaywallState: Error {}

typealias TriggerOutcomeResponsePipelineData = (
  request: PaywallPresentationRequest,
  triggerOutcome: TriggerResultOutcome,
  debugInfo: DebugInfo,
  responseIdentifiers: ResponseIdentifiers
)

extension AnyPublisher where Output == TriggerOutcomePipelineData, Failure == Error {
  func handleTriggerOutcome(
    _ cancellable: AnyCancellable?,
    configManager: ConfigManager = .shared
  ) -> AnyPublisher<TriggerOutcomeResponsePipelineData, PaywallState> {
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
          throw PaywallState.skipped(.holdout(experiment))
        case .noRuleMatch:
          SessionEventsManager.shared.triggerSession.activateSession(
            for: request.presentationInfo,
            on: request.presentingViewController,
            triggerResult: triggerOutcome.result
          )
          throw PaywallState.skipped(.noRuleMatch)
        case .triggerNotFound:
          throw PaywallState.skipped(.triggerNotFound)
        case let .error(error):
          Logger.debug(
            logLevel: .error,
            scope: .paywallPresentation,
            message: "Error Getting Paywall View Controller",
            info: debugInfo,
            error: error
          )
          throw PaywallState.skipped(.error(error))
        }
      }
      .eraseToAnyPublisher()
  }
}



