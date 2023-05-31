//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Requests the paywall view controller to present. If an error occurred during this,
  /// or a paywall is already presented, it cancels the pipeline and sends an `error`
  /// state to the paywall state publisher.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - experiment: The experiment that this paywall is part of.
  ///   - rulesOutput: The output from evaluating rules.
  ///   - debugInfo: Information to help with debugging.
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///   - dependencyContainer: Used with testing only.
  ///
  /// - Returns: A ``PaywallViewController``.
  func getPaywallViewController(
    request: PresentationRequest,
    experiment: Experiment?,
    rulesOutput: EvaluateRulesOutput,
    debugInfo: [String: Any],
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil,
    dependencyContainer: DependencyContainer? = nil
  ) async throws -> PaywallViewController {
    let dependencyContainer = dependencyContainer ?? self.dependencyContainer
    let responseIdentifiers = ResponseIdentifiers(
      paywallId: experiment?.variant.paywallId,
      experiment: experiment
    )
    let paywallRequest = dependencyContainer.makePaywallRequest(
      eventData: request.presentationInfo.eventData,
      responseIdentifiers: responseIdentifiers,
      overrides: .init(
        products: request.paywallOverrides?.products,
        isFreeTrial: request.presentationInfo.freeTrialOverride
      ),
      isDebuggerLaunched: request.flags.isDebuggerLaunched
    )
    do {
      let delegate = request.flags.type.getPaywallVcDelegateAdapter()
      let paywallViewController = try await dependencyContainer.paywallManager.getPaywallViewController(
        from: paywallRequest,
        isPreloading: false,
        delegate: delegate
      )

      return paywallViewController
    } catch {
      throw await presentationFailure(error, request, debugInfo, paywallStatePublisher)
    }
  }

  private func presentationFailure(
    _ error: Error,
    _ request: PresentationRequest,
    _ debugInfo: [String: Any],
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>?
  ) async -> Error {
    let subscriptionStatus = await request.flags.subscriptionStatus.async()
    if InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: subscriptionStatus == .active,
      overrides: .init(
        isDebuggerLaunched: request.flags.isDebuggerLaunched,
        shouldIgnoreSubscriptionStatus: request.paywallOverrides?.ignoreSubscriptionStatus
      )
    ) {
      let state: PaywallState = .skipped(.userIsSubscribed)
      paywallStatePublisher?.send(state)
      paywallStatePublisher?.send(completion: .finished)
      return PresentationPipelineError.userIsSubscribed
    }

    if request.flags.type != .getImplicitPresentationResult &&
      request.flags.type != .getPresentationResult {
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "Error Getting Paywall View Controller",
        info: debugInfo,
        error: error
      )
    }
    paywallStatePublisher?.send(.presentationError(error))
    paywallStatePublisher?.send(completion: .finished)
    return PresentationPipelineError.noPaywallViewController
  }
}
