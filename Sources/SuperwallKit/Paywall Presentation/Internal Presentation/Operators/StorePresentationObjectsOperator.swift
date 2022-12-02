//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/12/2022.
//

import UIKit
import Combine

extension AnyPublisher where Output == PresentablePipelineOutput, Failure == Error {
  /// Presents the paywall view controller, stores the presentation request for future use,
  /// and sends back a `presented` state to the paywall state publisher.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func storePresentationObjects(_ presentationSubject: PresentationSubject) -> AnyPublisher<PresentablePipelineOutput, Error> {
    map { input in
      let lastPaywallPresentation = LastPresentationItems(
        request: input.request,
        subject: presentationSubject
      )
      Superwall.shared.presentationItems.last = lastPaywallPresentation
      presentationSubject.send(completion: .finished)
      return input
    }
    .eraseToAnyPublisher()
  }
}
