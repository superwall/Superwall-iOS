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
        let sessionEventsManager = input.request.injections.sessionEventsManager
        await sessionEventsManager.triggerSession.activateSession(
          for: input.request.presentationInfo,
          on: input.request.presentingViewController,
          triggerResult: input.triggerResult
        )
        paywallStatePublisher.send(.skipped(.holdout(experiment)))
      case .noRuleMatch:
        let sessionEventsManager = input.request.injections.sessionEventsManager
        await sessionEventsManager.triggerSession.activateSession(
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
