//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/05/2023.
//

import Foundation
import Combine

extension AnyPublisher where Output == PresentablePipelineOutput, Failure == Error {
  /// Gets the ``PaywallViewController`` and sets it up before returning it.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains a ``PaywallViewController``.
  func extractPaywallViewController(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PaywallViewController, Error> {
    receive(on: DispatchQueue.main)
      .map { input in
        let paywallViewController = input.paywallViewController
        paywallViewController.set(
          eventData: input.request.presentationInfo.eventData,
          presentationStyleOverride: input.request.paywallOverrides?.presentationStyle,
          paywallStatePublisher: paywallStatePublisher
        )
        return input.paywallViewController
      }
      .eraseToAnyPublisher()
  }
}
