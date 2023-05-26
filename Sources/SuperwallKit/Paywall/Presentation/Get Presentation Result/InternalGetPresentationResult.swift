//
//  File.swift
//
//
//  Created by Yusuf Tör on 21/11/2022.
//

import Foundation
import Combine

extension Superwall {
  @discardableResult
  func getPresentationResult(for request: PresentationRequest) async -> PresentationResult {
    do {
      try await waitToPresent(request)
      let debugInfo = logPresentation(
        request: request,
        message: "Called Superwall.shared.getPresentationResult"
      )
      let rulesOutput = try await evaluateRules(from: request)

      let experiment = try await getExperiment(
        request: request,
        rulesOutput: rulesOutput
      )

      let paywallViewController = try await getPaywallViewController(
        request: request,
        experiment: experiment,
        rulesOutput: rulesOutput,
        debugInfo: debugInfo
      )

      try await getPresenter(
        for: paywallViewController,
        rulesOutput: rulesOutput,
        request: request,
        debugInfo: debugInfo
      )
      let presentationResult = GetPresentationResultLogic.convertTriggerResult(rulesOutput.triggerResult)
      return presentationResult
    } catch let error as PresentationPipelineError {
      return handle(error, requestType: request.flags.type)
    } catch {
      // Will never get here
      return .paywallNotAvailable
    }
  }

  /// Converts a thrown error into a ``PresentationResult`` object.
  ///
  /// - Parameters:
  ///   - error: The error that was thrown.
  ///   - requestType: The type of presentation request, as defined in `PresentationRequestType`.
  /// - Returns: A ``PresentationResult``.
  private func handle(
    _ error: PresentationPipelineError,
    requestType: PresentationRequestType
  ) -> PresentationResult {
    if requestType != .getImplicitPresentationResult {
      Logger.debug(
        logLevel: .info,
        scope: .paywallPresentation,
        message: "Paywall presentation error: \(error)"
      )
    }
    switch error {
    case .userIsSubscribed:
      return .userIsSubscribed
    case .noPaywallViewController:
      return .paywallNotAvailable
    case .noRuleMatch:
      return .noRuleMatch
    case .holdout(let experiment):
      return .holdout(experiment)
    case .eventNotFound:
      return .eventNotFound
    case .debuggerPresented,
      .noPresenter,
      .paywallAlreadyPresented,
      .noInternet:
      return .paywallNotAvailable
    }
  }
}
