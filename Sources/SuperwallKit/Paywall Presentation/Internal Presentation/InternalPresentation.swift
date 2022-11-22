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

extension Superwall {
  /// Runs a combine pipeline to present a paywall, publishing ``PaywallState`` objects that provide updates on the lifecycle of the paywall.
  ///
  /// - Parameters:
  ///   - request: A presentation request of type `PresentationRequest` to feed into a presentation pipeline.
  /// - Returns: A publisher that outputs a ``PaywallState``.
  func internallyPresent(_ request: PresentationRequest) -> PaywallStatePublisher {
    /// A passthrough subject which sends the paywall state back to the client.
    let paywallStatePublisher = PassthroughSubject<PaywallState, Never>()
    let presentationSubject = PresentationSubject(request)

    self.presentationPublisher = presentationSubject
      .eraseToAnyPublisher()
      .awaitIdentity()
      .logPresentation("Called Superwall.track")
      .checkForDebugger()
      .getTriggerResult()
      .confirmAssignment()
      .handleTriggerResult(paywallStatePublisher)
      .getPaywallViewController(paywallStatePublisher)
      .checkPaywallIsPresentable(paywallStatePublisher)
      .presentPaywall(paywallStatePublisher, presentationSubject)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )

    return paywallStatePublisher
      .eraseToAnyPublisher()
  }

  /// Presents the paywall again by sending the previous presentation request to the presentation publisher.
  ///
  /// - Parameters:
  ///   - presentationPublisher: The publisher created in the `internallyPresent(request:)` function to kick off the presentation pipeline.
  func presentAgain(using presentationPublisher: PresentationSubject) async {
    guard let request = Superwall.shared.lastSuccessfulPresentationRequest else {
      return
    }
    await MainActor.run {
      if let presentingPaywallIdentifier = Superwall.shared.paywallViewController?.paywall.identifier {
        PaywallManager.shared.removePaywall(withIdentifier: presentingPaywallIdentifier)
      }
    }

    // Resend both the identity and request again to run the presentation pipeline again.
    IdentityManager.shared.resendIdentity()
    presentationPublisher.send(request)
  }


  @MainActor
  func dismiss(
    _ paywallViewController: PaywallViewController,
    state: PaywallDismissedResult.DismissState,
    completion: (() -> Void)? = nil
  ) {
    let paywallInfo = paywallViewController.paywallInfo
    paywallViewController.dismiss(
      .withResult(
        paywallInfo: paywallInfo,
        state: state
      )
    ) {
      completion?()
    }
  }
}
