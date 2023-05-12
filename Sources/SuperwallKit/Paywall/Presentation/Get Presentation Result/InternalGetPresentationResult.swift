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
      await waitToPresent(request)
      let debugInfo = logPresentation(request, "Called Superwall.shared.track")
      let assignmentOutput = try await evaluateRules(
        from: request,
        debugInfo: debugInfo
      )

      let triggerResultOutput = try checkForPaywallResult(
        triggerResult: assignmentOutput.triggerResult,
        debugInfo: debugInfo
      )
      let paywallVcOutput = try await getPaywallViewController(request, triggerResultOutput)

      try await checkPaywallIsPresentable(
        input: paywallVcOutput,
        request: request
      )
      let presentationResult = GetPresentationResultLogic.convertTriggerResult(assignmentOutput.triggerResult)
      return presentationResult
    } catch let error as PresentationPipelineError {
      return handle(error, requestType: request.flags.type)
    } catch {
      // Will never get here
      return .paywallNotAvailable
    }
  }

  private func handle(
    _ error: PresentationPipelineError,
    requestType: PresentationRequestType
  ) -> PresentationResult {
    if requestType != .getImplicitPresentationResult {
      Logger.debug(
        logLevel: .info,
        scope: .paywallPresentation,
        message: "Skipped paywall presentation: \(error)"
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
      .paywallAlreadyPresented:
      // Won't get here
      return .paywallNotAvailable
    }
  }
}
