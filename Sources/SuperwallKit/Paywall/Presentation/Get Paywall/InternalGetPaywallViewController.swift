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
  func internallyGetPaywallViewController(
    _ request: PresentationRequest
  ) -> AnyPublisher<PaywallViewController, Error> {
    let paywallStatePublisher: PassthroughSubject<PaywallState, Never> = .init()
    let presentationSubject = PresentationSubject(request)

    return presentationSubject
      .eraseToAnyPublisher()
      .waitToPresent()
      .logPresentation("Called Superwall.shared.getPaywallViewController")
      .evaluateRules()
      .confirmHoldoutAssignment()
      .handleTriggerResult(paywallStatePublisher)
      .getPaywallViewController(pipelineType: .presentation(paywallStatePublisher))
      .checkSubscriptionStatus(paywallStatePublisher)
      .confirmPaywallAssignment()
      .storePresentationObjects(presentationSubject, paywallStatePublisher)
      .logErrors(from: request)
      .extractPaywallViewController(paywallStatePublisher)
  }
}
