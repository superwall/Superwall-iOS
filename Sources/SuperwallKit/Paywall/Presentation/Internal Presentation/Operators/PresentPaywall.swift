//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import UIKit
import Combine

extension Superwall {
  /// Presents the paywall view controller, stores the presentation request for future use,
  /// and sends back a `presented` state to the paywall state publisher.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  @MainActor
  func presentPaywallViewController(
    _ paywallViewController: PaywallViewController,
    on presenter: UIViewController,
    debugInfo: [String: Any],
    request: PresentationRequest,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async throws {
    Task.detached { [weak self] in
      guard let self = self else {
        return
      }
      let trackedEvent = InternalSuperwallEvent.PresentationRequest(
        eventData: request.presentationInfo.eventData,
        type: request.flags.type,
        status: .presentation,
        statusReason: nil,
        factory: self.dependencyContainer
      )
      await self.track(trackedEvent)
    }

    try await withCheckedThrowingContinuation { continuation in
      paywallViewController.present(
        on: presenter,
        request: request,
        presentationStyleOverride: request.paywallOverrides?.presentationStyle,
        paywallStatePublisher: paywallStatePublisher
      ) { isPresented in
        if isPresented {
          let state: PaywallState = .presented(paywallViewController.info)
          paywallStatePublisher.send(state)
          continuation.resume()
        } else {
          Logger.debug(
            logLevel: .info,
            scope: .paywallPresentation,
            message: "Paywall Already Presented",
            info: debugInfo
          )
          let error = InternalPresentationLogic.presentationError(
            domain: "SWKPresentationError",
            code: 102,
            title: "Paywall Already Presented",
            value: "Trying to present paywall while another paywall is presented."
          )
          paywallStatePublisher.send(.presentationError(error))
          paywallStatePublisher.send(completion: .finished)
          continuation.resume(with: .failure(PresentationPipelineError.paywallAlreadyPresented))
        }
      }
    }
  }
}
