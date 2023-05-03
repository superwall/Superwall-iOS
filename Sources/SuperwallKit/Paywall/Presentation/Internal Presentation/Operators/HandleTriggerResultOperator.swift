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
  let confirmableAssignment: ConfirmableAssignment?
  let experiment: Experiment
}

extension AnyPublisher where Output == AssignmentPipelineOutput, Failure == Error {
  /// Switches over the trigger result. The pipeline continues if a paywall will show.
  /// Otherwise, it sends a `skipped` state to the paywall state publisher and cancels
  /// the pipeline.
  /// 
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func handleTriggerResult(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<TriggerResultResponsePipelineOutput, Error> {
    asyncMap { input in
      let errorType: PresentationPipelineError

      switch input.triggerResult {
      case .paywall(let experiment):
        return TriggerResultResponsePipelineOutput(
          request: input.request,
          triggerResult: input.triggerResult,
          debugInfo: input.debugInfo,
          confirmableAssignment: input.confirmableAssignment,
          experiment: experiment
        )
      case .holdout(let experiment):
        let sessionEventsManager = input.request.dependencyContainer.sessionEventsManager
        await sessionEventsManager?.triggerSession.activateSession(
          for: input.request.presentationInfo,
          on: input.request.presenter,
          triggerResult: input.triggerResult
        )
        errorType = .holdout(experiment)
        paywallStatePublisher.send(.skipped(.holdout(experiment)))
      case .noRuleMatch:
        let sessionEventsManager = input.request.dependencyContainer.sessionEventsManager
        await sessionEventsManager?.triggerSession.activateSession(
          for: input.request.presentationInfo,
          on: input.request.presenter,
          triggerResult: input.triggerResult
        )
        errorType = .noRuleMatch
        paywallStatePublisher.send(.skipped(.noRuleMatch))
      case .eventNotFound:
        errorType = .eventNotFound
        paywallStatePublisher.send(.skipped(.eventNotFound))
      case let .error(error):
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Error Getting Paywall View Controller",
          info: input.debugInfo,
          error: error
        )
        errorType = .noPaywallViewController
        paywallStatePublisher.send(.skipped(.error(error)))
      }

      paywallStatePublisher.send(completion: .finished)
      throw errorType
    }
    .eraseToAnyPublisher()
  }
}
