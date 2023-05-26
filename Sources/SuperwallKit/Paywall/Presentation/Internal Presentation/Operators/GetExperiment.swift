//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Switches over the trigger result. Continues if a paywall will show.
  /// Otherwise, if applicable, it sends a `skipped` state to the paywall state publisher and returns.
  ///
  /// - Parameters:
  ///   - request: The `PresentationRequest`.
  ///   - rulesOutput: The output from evaluating the rules.
  ///   - debugInfo: Information to help with debugging.
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A struct that contains info for the next operation.
  func getExperiment(
    request: PresentationRequest,
    rulesOutput: EvaluateRulesOutput,
    debugInfo: [String: Any]? = nil,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil
  ) async throws -> Experiment {
    let errorType: PresentationPipelineError

    switch rulesOutput.triggerResult {
    case .paywall(let experiment):
      return experiment
    case .holdout(let experiment):
      await activateSession(request: request, rulesOutput: rulesOutput)
      errorType = .holdout(experiment)
      paywallStatePublisher?.send(.skipped(.holdout(experiment)))
    case .noRuleMatch:
      await activateSession(request: request, rulesOutput: rulesOutput)
      errorType = .noRuleMatch
      paywallStatePublisher?.send(.skipped(.noRuleMatch))
    case .eventNotFound:
      errorType = .eventNotFound
      paywallStatePublisher?.send(.skipped(.eventNotFound))
    case let .error(error):
      if request.flags.type == .getImplicitPresentationResult ||
        request.flags.type == .getPresentationResult {
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Error Getting Paywall View Controller",
          info: debugInfo,
          error: error
        )
      }
      errorType = .noPaywallViewController
      paywallStatePublisher?.send(.presentationError(error))
    }

    paywallStatePublisher?.send(completion: .finished)
    throw errorType
  }

  private func activateSession(
    request: PresentationRequest,
    rulesOutput: EvaluateRulesOutput
  ) async {
    if request.flags.type == .getImplicitPresentationResult ||
      request.flags.type == .getPresentationResult {
      return
    }
    let sessionEventsManager = dependencyContainer.sessionEventsManager
    await sessionEventsManager?.triggerSession.activateSession(
      for: request.presentationInfo,
      on: request.presenter,
      triggerResult: rulesOutput.triggerResult
    )
  }
}
