//
//  HeadlessPresentation.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 04/11/2026.
//

import Combine

extension Superwall {
  #if !canImport(WebKit)
  /// Runs a `register` call on watchOS and tvOS, which can't show paywalls.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - publisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  func internallyPresent(
    _ request: PresentationRequest,
    _ publisher: PassthroughSubject<PaywallState, Never>
  ) async {
    do {
      try await waitForSubsStatusAndConfig(request, paywallStatePublisher: publisher)

      let debugInfo = log(request: request)
      let audienceOutcome = try await evaluateAudienceFilter(from: request)

      confirmHoldoutAssignment(
        request: request,
        from: audienceOutcome
      )

      try await finishWithoutPaywallUI(
        request: request,
        audienceOutcome: audienceOutcome,
        debugInfo: debugInfo,
        publisher: publisher
      )
    } catch {
      logErrors(from: request, error)
    }
  }

  /// Evaluates the audience filters for a presentation result, confirming
  /// assignments as iOS does.
  ///
  /// iOS also loads the paywall to check it can be shown. There's nothing to
  /// load here, so the result says which paywall the user would see.
  func getAudienceOutcome(
    _ request: PresentationRequest
  ) async throws -> AudienceFilterEvaluationOutcome {
    try await waitForSubsStatusAndConfig(request, paywallStatePublisher: nil)
    let audienceOutcome = try await evaluateAudienceFilter(from: request)
    confirmHoldoutAssignment(
      request: request,
      from: audienceOutcome
    )
    confirmPaywallAssignment(
      audienceOutcome.assignment,
      request: request,
      isDebuggerLaunched: request.flags.isDebuggerLaunched
    )
    return audienceOutcome
  }
  #endif

  /// Ends a `register` call once the audience filters have run, on a platform
  /// that can't show paywalls.
  ///
  /// A holdout or a placement with no matching audience is skipped and runs
  /// the feature, as it would on iOS. When a paywall would be shown, the
  /// handler gets an error instead and the feature doesn't run, the same as
  /// when a paywall fails to load on iOS.
  ///
  /// Built on every platform so the iOS tests cover it.
  func finishWithoutPaywallUI(
    request: PresentationRequest,
    audienceOutcome: AudienceFilterEvaluationOutcome,
    debugInfo: [String: Any],
    publisher: PassthroughSubject<PaywallState, Never>
  ) async throws {
    // Sends `skipped` and throws for anything other than a paywall.
    _ = try await getExperiment(
      request: request,
      audienceOutcome: audienceOutcome,
      debugInfo: debugInfo,
      paywallStatePublisher: publisher,
      storage: dependencyContainer.storage
    )

    Logger.debug(
      logLevel: .warn,
      scope: .paywallPresentation,
      message: "A campaign matched, but paywalls can't be shown on this platform.",
      info: debugInfo
    )
    let error = InternalPresentationLogic.presentationError(
      domain: "SWKPresentationError",
      code: 108,
      title: "Paywalls Unavailable",
      value: "Paywalls can't be shown on watchOS or tvOS."
    )
    publisher.send(.presentationError(error))
    publisher.send(completion: .finished)
    throw PresentationPipelineError.noPaywallViewController
  }
}
