//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/08/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Runs a pipeline of operations to get a paywall to present and associated components.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - publisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  /// - Returns: A `PaywallComponents` object that contains objects associated with the
  /// paywall view controller.
  /// - Throws: A `PresentationPipelineError` object associated with stages of the pipeline.
  func getPaywallComponents(
    _ request: PresentationRequest,
    _ publisher: PassthroughSubject<PaywallState, Never>? = nil
  ) async throws -> PaywallComponents {
    try await waitForSubsStatusAndConfig(request, paywallStatePublisher: publisher)

    let debugInfo = logPresentation(request: request)

    try checkDebuggerPresentation(
      request: request,
      paywallStatePublisher: publisher
    )

    let audienceOutcome = try await evaluateAudienceFilter(from: request)

    try await checkUserSubscription(
      request: request,
      triggerResult: audienceOutcome.triggerResult,
      paywallStatePublisher: publisher
    )

    confirmHoldoutAssignment(
      request: request,
      from: audienceOutcome
    )

    let paywallViewController = try await getPaywallViewController(
      request: request,
      audienceOutcome: audienceOutcome,
      debugInfo: debugInfo,
      paywallStatePublisher: publisher,
      dependencyContainer: dependencyContainer
    )

    let presenter = try await getPresenterIfNecessary(
      for: paywallViewController,
      audienceOutcome: audienceOutcome,
      request: request,
      debugInfo: debugInfo,
      paywallStatePublisher: publisher
    )

    confirmPaywallAssignment(
      audienceOutcome.confirmableAssignment,
      request: request,
      isDebuggerLaunched: request.flags.isDebuggerLaunched
    )

    return PaywallComponents(
      viewController: paywallViewController,
      presenter: presenter,
      audienceOutcome: audienceOutcome,
      debugInfo: debugInfo
    )
  }
}
