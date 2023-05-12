//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Runs a combine pipeline to get a paywall to present, publishing ``PaywallState`` objects that provide updates on the lifecycle of the paywall.
  ///
  /// - Parameters:
  ///   - request: A presentation request of type `PresentationRequest` to feed into a presentation pipeline.
  ///
  /// - Returns: A ``PaywallViewController`` to present.
  @discardableResult
  func getPaywallViewController(
    _ request: PresentationRequest
  ) async throws -> PaywallViewController {
    do {
      let publisher: PassthroughSubject<PaywallState, Never> = .init()

      await waitToPresent(request)
      let debugInfo = logPresentation(request, "Called Superwall.shared.track")

      let assignmentOutput = try await evaluateRules(
        from: request,
        debugInfo: debugInfo
      )

      confirmHoldoutAssignment(input: assignmentOutput)
      let triggerResultOutput = try await handleTriggerResult(request, assignmentOutput, publisher)
      let paywallVcOutput = try await getPaywallViewController(request, triggerResultOutput, publisher)
      let presentableOutput = try await checkSubscriptionStatus(request, paywallVcOutput, publisher)

      confirmPaywallAssignment(
        request: request,
        input: presentableOutput
      )

      let paywallViewController = presentableOutput.paywallViewController
      await paywallViewController.set(
        request: request,
        paywallStatePublisher: publisher
      )
      return paywallViewController
    } catch {
      let toObjc = request.flags.type.hasObjcDelegate()
      logErrors(from: request, error)
      throw mapError(error, toObjc: toObjc)
    }
  }
}
