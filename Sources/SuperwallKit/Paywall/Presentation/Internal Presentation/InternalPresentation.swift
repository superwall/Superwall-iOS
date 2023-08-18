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
        try await waitToPresent(request, paywallStatePublisher: publisher)
        let debugInfo = logPresentation(
          request: request,
          message: "Called Superwall.shared.register"
        )

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

        confirmHoldoutAssignment(from: rulesOutcome)

        let experiment = try await getExperiment(
          request: request,
          rulesOutcome: rulesOutcome,
          debugInfo: debugInfo,
          paywallStatePublisher: publisher
        )
        let paywallViewController = try await getPaywallViewController(
          request: request,
          experiment: experiment,
          debugInfo: debugInfo,
          paywallStatePublisher: publisher
        )

        guard let presenter = try await getPresenter(
          for: paywallViewController,
          rulesOutcome: rulesOutcome,
          request: request,
          debugInfo: debugInfo,
          paywallStatePublisher: publisher
        ) else {
          return
        }

        confirmPaywallAssignment(
          rulesOutcome.confirmableAssignment,
          isDebuggerLaunched: request.flags.isDebuggerLaunched
        )

        try await presentPaywallViewController(
          paywallViewController,
          on: presenter,
          unsavedOccurrence: rulesOutcome.unsavedOccurrence,
          debugInfo: debugInfo,
          request: request,
          paywallStatePublisher: publisher
        )
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
