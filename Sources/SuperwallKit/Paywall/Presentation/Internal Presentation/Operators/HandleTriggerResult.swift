//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

struct TriggerResultResponsePipelineOutput {
  let triggerResult: TriggerResult
  let debugInfo: [String: Any]
  let confirmableAssignment: ConfirmableAssignment?
  let experiment: Experiment
}

extension Superwall {
  /// Switches over the trigger result. The pipeline continues if a paywall will show.
  /// Otherwise, it sends a `skipped` state to the paywall state publisher and cancels
  /// the pipeline.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func handleTriggerResult(
    _ request: PresentationRequest,
    _ input: AssignmentPipelineOutput,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async throws -> TriggerResultResponsePipelineOutput {
    let errorType: PresentationPipelineError

    switch input.triggerResult {
    case .paywall(let experiment):
      return TriggerResultResponsePipelineOutput(
        triggerResult: input.triggerResult,
        debugInfo: input.debugInfo,
        confirmableAssignment: input.confirmableAssignment,
        experiment: experiment
      )
    case .holdout(let experiment):
      let sessionEventsManager = dependencyContainer.sessionEventsManager
      await sessionEventsManager?.triggerSession.activateSession(
        for: request.presentationInfo,
        on: request.presenter,
        triggerResult: input.triggerResult
      )
      errorType = .holdout(experiment)
      paywallStatePublisher.send(.skipped(.holdout(experiment)))
    case .noRuleMatch:
      let sessionEventsManager = dependencyContainer.sessionEventsManager
      await sessionEventsManager?.triggerSession.activateSession(
        for: request.presentationInfo,
        on: request.presenter,
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
      paywallStatePublisher.send(.presentationError(error))
    }

    paywallStatePublisher.send(completion: .finished)
    throw errorType
  }
}
