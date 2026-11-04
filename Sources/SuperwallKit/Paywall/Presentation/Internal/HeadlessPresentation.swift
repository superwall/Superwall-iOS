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
  /// It ends the way iOS does when it has no internet connection:
  ///
  /// - A holdout or a placement with no matching audience is skipped, and the
  ///   feature runs.
  /// - If the paywall can't be fetched, the handler gets the error and the
  ///   feature doesn't run.
  /// - Otherwise the paywall is declined as if its page failed to load. A
  ///   non-gated feature runs, and a gated one gets an error instead.
  ///
  /// Built on every platform so the iOS tests cover it.
  ///
  /// - Parameter getPaywall: Fetches the paywall. Replaced in tests.
  func finishWithoutPaywallUI(
    request: PresentationRequest,
    audienceOutcome: AudienceFilterEvaluationOutcome,
    debugInfo: [String: Any],
    publisher: PassthroughSubject<PaywallState, Never>,
    getPaywall: ((PaywallRequest) async throws -> Paywall)? = nil
  ) async throws {
    // Sends `skipped` and throws for anything other than a paywall.
    let experiment = try await getExperiment(
      request: request,
      audienceOutcome: audienceOutcome,
      debugInfo: debugInfo,
      paywallStatePublisher: publisher,
      storage: dependencyContainer.storage
    )

    let paywallRequest = dependencyContainer.makePaywallRequest(
      placementData: request.presentationInfo.placementData,
      responseIdentifiers: ResponseIdentifiers(
        paywallId: experiment.variant.paywallId,
        experiment: experiment
      ),
      overrides: .init(
        isFreeTrial: request.presentationInfo.freeTrialOverride,
        featureGatingBehavior: request.paywallOverrides?.featureGatingBehavior
      ),
      isDebuggerLaunched: request.flags.isDebuggerLaunched,
      presentationSourceType: request.presentationSourceType
    )

    var paywall: Paywall
    do {
      let getPaywall = getPaywall ?? dependencyContainer.paywallManager.getPaywall(from:)
      paywall = try await getPaywall(paywallRequest)
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "Error Getting Paywall",
        info: debugInfo,
        error: error
      )
      publisher.send(.presentationError(error))
      publisher.send(completion: .finished)
      throw PresentationPipelineError.noPaywallViewController
    }

    Logger.debug(
      logLevel: .warn,
      scope: .paywallPresentation,
      message: "A campaign matched, but paywalls can't be shown on this platform. "
        + "It's declined as if the paywall failed to load.",
      info: debugInfo
    )
    paywall.closeReason = .webViewFailedToLoad
    let paywallInfo = paywall.getInfo(fromPlacement: request.presentationInfo.placementData)
    publisher.send(.dismissed(paywallInfo, .declined))
    publisher.send(completion: .finished)
  }
}
