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
  ///   - feature: The feature block passed to `register`, run when the
  ///     matched paywall isn't gated.
  func internallyPresent(
    _ request: PresentationRequest,
    _ publisher: PassthroughSubject<PaywallState, Never>,
    feature: (() -> Void)?
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
        publisher: publisher,
        feature: feature
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
  /// The feature is unlocked or not as on iOS when a paywall fails to load,
  /// but without the paywall's present and dismiss callbacks, since nothing
  /// was shown:
  ///
  /// - A holdout or a placement with no matching audience is skipped, and the
  ///   feature runs.
  /// - If the paywall can't be fetched, the handler gets the error and the
  ///   feature doesn't run.
  /// - A non-gated paywall runs the feature.
  /// - A gated paywall sends an error and doesn't run the feature.
  ///
  /// Built on every platform so the iOS tests cover it.
  ///
  /// - Parameters:
  ///   - feature: The feature block passed to `register`, if any.
  ///   - getPaywall: Fetches the paywall. Replaced in tests.
  func finishWithoutPaywallUI(
    request: PresentationRequest,
    audienceOutcome: AudienceFilterEvaluationOutcome,
    debugInfo: [String: Any],
    publisher: PassthroughSubject<PaywallState, Never>,
    feature: (() -> Void)?,
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

    let paywall: Paywall
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

    switch paywall.featureGating {
    case .nonGated:
      Logger.debug(
        logLevel: .warn,
        scope: .paywallPresentation,
        message: "A campaign matched, but paywalls can't be shown on this platform. "
          + "The paywall isn't gated, so the feature runs.",
        info: debugInfo
      )
      publisher.send(completion: .finished)
      await MainActor.run {
        feature?()
      }
    case .gated:
      let error = InternalPresentationLogic.presentationError(
        domain: "SWKPresentationError",
        code: 106,
        title: "Webview Unavailable",
        value: "Trying to present a gated paywall, but paywalls can't be shown on this platform."
      )
      publisher.send(.presentationError(error))
      publisher.send(completion: .finished)
    }
  }
}
