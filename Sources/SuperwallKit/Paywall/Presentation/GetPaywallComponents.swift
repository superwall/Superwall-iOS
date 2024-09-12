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

    let debugInfo = log(request: request)

    try checkDebuggerPresentation(
      request: request,
      paywallStatePublisher: publisher
    )

    let rulesOutcome = try await evaluateRules(from: request)

    try await checkUserSubscription(
      request: request,
      triggerResult: rulesOutcome.triggerResult,
      paywallStatePublisher: publisher
    )

    confirmHoldoutAssignment(
      request: request,
      from: rulesOutcome
    )

    let paywallViewController = try await getPaywallViewController(
      request: request,
      rulesOutcome: rulesOutcome,
      debugInfo: debugInfo,
      paywallStatePublisher: publisher,
      dependencyContainer: dependencyContainer
    )

    let presenter = try await getPresenterIfNecessary(
      for: paywallViewController,
      rulesOutcome: rulesOutcome,
      request: request,
      debugInfo: debugInfo,
      paywallStatePublisher: publisher
    )

    confirmPaywallAssignment(
      rulesOutcome.confirmableAssignment,
      request: request,
      isDebuggerLaunched: request.flags.isDebuggerLaunched
    )

    return PaywallComponents(
      viewController: paywallViewController,
      presenter: presenter,
      rulesOutcome: rulesOutcome,
      debugInfo: debugInfo
    )
  }

  func confirmAssignments(
    _ request: PresentationRequest
  ) async -> ConfirmedAssignment? {
    do {
      try await waitForSubsStatusAndConfig(request, paywallStatePublisher: nil)

      let rulesOutcome = try await evaluateRules(from: request)

      confirmHoldoutAssignment(
        request: request,
        from: rulesOutcome
      )

      let confirmableAssignment = rulesOutcome.confirmableAssignment

      confirmPaywallAssignment(
        confirmableAssignment,
        request: request,
        isDebuggerLaunched: request.flags.isDebuggerLaunched
      )

      if let confirmableAssignment = confirmableAssignment {
        return ConfirmedAssignment(
          experimentId: confirmableAssignment.experimentId,
          variant: confirmableAssignment.variant
        )
      }
      return nil
    } catch {
      return nil
    }
  }
}
