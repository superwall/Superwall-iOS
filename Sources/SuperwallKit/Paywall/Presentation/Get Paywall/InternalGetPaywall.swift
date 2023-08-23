//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Gets a paywall to present, publishing ``PaywallState`` objects that provide updates on the lifecycle of the paywall.
  ///
  /// - Parameters:
  ///   - request: A presentation request of type `PresentationRequest` to feed into a presentation pipeline.
  ///
  /// - Returns: A ``PaywallViewController`` to present.
  @discardableResult
  func getPaywall(
    _ request: PresentationRequest
  ) async throws -> PaywallViewController {
    do {
      let publisher: PassthroughSubject<PaywallState, Never> = .init()
      try await waitToPresent(request, paywallStatePublisher: publisher)

      let debugInfo = logPresentation(
        request: request,
        message: "Called Superwall.shared.getPaywall"
      )

      let rulesOutcome = try await evaluateRules(from: request)

      confirmHoldoutAssignment(from: rulesOutcome)

      let paywallViewController = try await getPaywallViewController(
        request: request,
        rulesOutcome: rulesOutcome,
        debugInfo: debugInfo,
        paywallStatePublisher: publisher
      )

      try await checkSubscriptionStatus(
        request: request,
        paywall: paywallViewController.paywall,
        triggerResult: rulesOutcome.triggerResult,
        paywallStatePublisher: publisher
      )

      confirmPaywallAssignment(
        rulesOutcome.confirmableAssignment,
        isDebuggerLaunched: request.flags.isDebuggerLaunched
      )

      await paywallViewController.set(
        request: request,
        paywallStatePublisher: publisher,
        unsavedOccurrence: rulesOutcome.unsavedOccurrence
      )
      return paywallViewController
    } catch {
      let toObjc = request.flags.type.hasObjcDelegate()
      logErrors(from: request, error)
      throw mapError(error, toObjc: toObjc)
    }
  }
}
