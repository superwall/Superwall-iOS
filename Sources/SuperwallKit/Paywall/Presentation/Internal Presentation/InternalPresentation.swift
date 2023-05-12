//
//  InternalPaywallPresentation.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import UIKit
import Combine

/// A CurrentValueSubject that emits `PresentationRequest` objects.
typealias PresentationSubject = CurrentValueSubject<PresentationRequest, Error>

/// A publisher that emits ``PaywallState`` objects.
public typealias PaywallStatePublisher = AnyPublisher<PaywallState, Never>
typealias PresentablePipelineOutputPublisher = AnyPublisher<PresentablePipelineOutput, Error>

extension Superwall {
  /// Runs a background task to present a paywall, publishing ``PaywallState`` objects that provide updates on the lifecycle of the paywall.
  ///
  /// - Parameters:
  ///   - request: A presentation request of type `PresentationRequest` to feed into a presentation pipeline.
  ///   - paywallStatePublisher: A publisher fed into the pipeline that sends state updates. Defaults to `init()` and used by `presentAgain()` to pass in the existing state publisher.
  /// - Returns: A publisher that outputs a ``PaywallState``.
  @discardableResult
  func internallyPresent(
    _ request: PresentationRequest,
    _ publisher: PassthroughSubject<PaywallState, Never> = .init()
  ) -> PaywallStatePublisher {
    Task {
      do {
        try await checkNoPaywallAlreadyPresented(request, publisher)
        await waitToPresent(request)
        let debugInfo = logPresentation(request, "Called Superwall.shared.track")
        try checkDebuggerPresentation(request, publisher)
        let assignmentOutput = try await evaluateRules(request, debugInfo: debugInfo)
        try await checkUserSubscription(request, assignmentOutput.triggerResult, publisher)
        confirmHoldoutAssignment(input: assignmentOutput)
        let triggerResultOutput = try await handleTriggerResult(request, assignmentOutput, publisher)
        let paywallVcOutput = try await getPaywallViewController(request, triggerResultOutput, publisher)

        let presentableOutput = try await checkPaywallIsPresentable(
          input: paywallVcOutput,
          request: request,
          publisher
        )
        
        confirmPaywallAssignment(request: request, input: presentableOutput)
        try await presentPaywall(request, presentableOutput, publisher)
        storePresentationObjects(request, publisher)
      } catch {
        logErrors(from: request, error)
      }
    }

    return publisher
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  @MainActor
  func dismiss(
    _ paywallViewController: PaywallViewController,
    result: PaywallResult,
    closeReason: PaywallCloseReason = .systemLogic,
    completion: (() -> Void)? = nil
  ) {
    paywallViewController.dismiss(
      result: result,
      closeReason: closeReason
    ) {
      completion?()
    }
  }
}
