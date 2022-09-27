//
//  InternalPaywallPresentation.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import UIKit
import Combine

extension Paywall {
  /// Runs a combine pipeline to present a paywall, publishing ``PaywallState`` objects that provide updates on the lifecycle of the paywall.
  ///
  /// - Parameters:
  ///   - request: A presentation request of type `PaywallPresentationRequest` to feed into a presentation pipeline.
  /// - Returns: A publisher that outputs a ``PaywallState``.
  func internallyPresent(_ request: PaywallPresentationRequest) -> AnyPublisher<PaywallState, Never> {
    let paywallStatePublisher = PassthroughSubject<PaywallState, Never>()
    let presentationPublisher = CurrentValueSubject<PaywallPresentationRequest, Error>(request)

    self.presentationPublisher = presentationPublisher
      .eraseToAnyPublisher()
      .awaitIdentity()
      .logPresentation()
      .checkForDebugger()
      .getTriggerOutcome()
      .confirmAssignment()
      .handleTriggerOutcome(paywallStatePublisher)
      .getPaywallViewController(paywallStatePublisher)
      .checkPaywallIsPresentable(paywallStatePublisher)
      .presentPaywall(paywallStatePublisher, presentationPublisher)
      .eraseToAnyPublisher()
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
  func presentAgain(
    using presentationPublisher: CurrentValueSubject<PaywallPresentationRequest, Error>
  ) async {
    guard let request = Paywall.shared.lastSuccessfulPresentationRequest else {
      return
    }
    await MainActor.run {
      if let presentingPaywallIdentifier = Paywall.shared.paywallViewController?.paywallResponse.identifier {
        PaywallManager.shared.removePaywall(withIdentifier: presentingPaywallIdentifier)
      }
    }
    let hasIdentity = IdentityManager.shared.hasIdentity.value
    IdentityManager.shared.hasIdentity.send(hasIdentity)
    presentationPublisher.send(request)
  }

  func dismiss(
    _ paywallViewController: SWPaywallViewController,
    state: PaywallDismissedResult.DismissState,
    completion: (() -> Void)? = nil
  ) {
    onMain {
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

  func destroyPresentingWindow() {
    presentingWindow?.isHidden = true
    presentingWindow = nil
  }
}
