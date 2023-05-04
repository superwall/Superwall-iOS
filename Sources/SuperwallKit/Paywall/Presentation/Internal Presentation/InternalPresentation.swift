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
  /// Runs a combine pipeline to present a paywall, publishing ``PaywallState`` objects that provide updates on the lifecycle of the paywall.
  ///
  /// - Parameters:
  ///   - request: A presentation request of type `PresentationRequest` to feed into a presentation pipeline.
  ///   - paywallStatePublisher: A publisher fed into the pipeline that sends state updates. Defaults to `init()` and used by `presentAgain()` to pass in the existing state publisher.
  /// - Returns: A publisher that outputs a ``PaywallState``.
  @discardableResult
  func internallyPresent(
    _ request: PresentationRequest,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never> = .init()
  ) -> PaywallStatePublisher {
    let presentationSubject = PresentationSubject(request)

    presentationSubject
      .eraseToAnyPublisher()
      .checkNoPaywallAlreadyPresented(paywallStatePublisher)
      .waitToPresent()
      .logPresentation("Called Superwall.shared.track")
      .checkDebuggerPresentation(paywallStatePublisher)
      .evaluateRules()
      .checkUserSubscription(paywallStatePublisher)
      .confirmHoldoutAssignment()
      .handleTriggerResult(paywallStatePublisher)
      .getPaywallViewController(pipelineType: .presentation(paywallStatePublisher))
      .checkPaywallIsPresentable(paywallStatePublisher)
      .confirmPaywallAssignment()
      .presentPaywall(paywallStatePublisher)
      .storePresentationObjects(presentationSubject, paywallStatePublisher)
      .logErrors(from: request)
      .subscribe(Subscribers.Sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      ))

    return paywallStatePublisher
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  /// Presents the paywall again by sending the previous presentation request to the presentation publisher.
  func presentAgain(cacheKey: String) {
    guard let lastPresentationItems = presentationItems.last else {
      return
    }

    // Remove the currently presenting paywall from cache.
    dependencyContainer.paywallManager.removePaywallViewController(forKey: cacheKey)

    // Resend the request and pass in the state publisher so it can continue
    // to send updates.
    internallyPresent(
      lastPresentationItems.request,
      lastPresentationItems.statePublisher
    )
  }

  @MainActor
  func dismiss(
    _ paywallViewController: PaywallViewController,
    result: PaywallResult,
    shouldSendPaywallResult: Bool = true,
    shouldCompleteStatePublisher: Bool = true,
    closeReason: PaywallCloseReason = .systemLogic,
    completion: (() -> Void)? = nil
  ) {
    paywallViewController.dismiss(
      result: result,
      shouldSendPaywallResult: shouldSendPaywallResult,
      shouldCompleteStatePublisher: shouldCompleteStatePublisher,
      closeReason: closeReason
    ) {
      completion?()
    }
  }
}
