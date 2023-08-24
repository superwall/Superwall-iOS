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
      let paywallComponents = try await getPaywallComponents(request)
      let triggerResult = paywallComponents.rulesOutcome.triggerResult
      let presentationResult = GetPresentationResultLogic.convertTriggerResult(triggerResult)
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
      .noConfig,
      .subscriptionStatusTimeout:
      return .paywallNotAvailable
    }
  }
}
