//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/08/2023.
//

import Foundation
import Combine

extension Superwall {
  #if canImport(WebKit)
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
    var request = request
    try await waitForSubsStatusAndConfig(request, paywallStatePublisher: publisher)

    let debugInfo = log(request: request)

    try checkDebuggerPresentation(
      request: request,
      paywallStatePublisher: publisher
    )

    let audienceOutcome = try await Self.evaluatingAudience(
      of: &request,
      activeEntitlementIds: { Set(self.entitlements.active.map { $0.id }) },
      evaluate: { try await self.evaluateAudienceFilter(from: $0) }
    )

    confirmHoldoutAssignment(
      request: request,
      from: audienceOutcome
    )

    let (paywallViewController, paywall) = try await getPaywallViewController(
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
      audienceOutcome.assignment,
      request: request,
      isDebuggerLaunched: request.flags.isDebuggerLaunched
    )

    return PaywallComponents(
      viewController: paywallViewController,
      paywall: paywall,
      presenter: presenter,
      audienceOutcome: audienceOutcome,
      debugInfo: debugInfo,
      request: request
    )
  }
  #endif

  func confirmAssignments(
    _ request: PresentationRequest
  ) async -> Assignment? {
    do {
      try await waitForSubsStatusAndConfig(request, paywallStatePublisher: nil)

      let rulesOutcome = try await evaluateAudienceFilter(from: request)

      confirmHoldoutAssignment(
        request: request,
        from: rulesOutcome
      )

      let assignment = rulesOutcome.assignment

      confirmPaywallAssignment(
        assignment,
        request: request,
        isDebuggerLaunched: request.flags.isDebuggerLaunched
      )

      return assignment
    } catch {
      return nil
    }
  }

  /// Evaluates the audience and records what it may have seen. Building the audience's
  /// attributes waits, so entitlements can become active part-way through: everything active
  /// before or after counts as seen, and the time is taken once it's done. A paywall shown
  /// to a subscriber on purpose, such as an upgrade offer, is never taken for one whose
  /// entitlements arrived while it loaded.
  static func evaluatingAudience<Outcome>(
    of request: inout PresentationRequest,
    activeEntitlementIds: () -> Set<String>,
    now: () -> Date = Date.init,
    evaluate: (PresentationRequest) async throws -> Outcome
  ) async rethrows -> Outcome {
    let activeBefore = activeEntitlementIds()
    let outcome = try await evaluate(request)
    request.entitlementIdsSeenByAudience = activeBefore.union(activeEntitlementIds())
    request.audienceEvaluatedAt = now()
    return outcome
  }
}
