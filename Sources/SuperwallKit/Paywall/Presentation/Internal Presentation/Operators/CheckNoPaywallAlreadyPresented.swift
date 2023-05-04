//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/03/2023.
//


import Foundation
import Combine

extension AnyPublisher where Output == PresentationRequest, Failure == Error {
  /// Checks that there isn't already a paywall being presented.
  ///
  /// - Parameter paywallStatePublisher: The publisher that sends state updates.
  func checkNoPaywallAlreadyPresented(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PresentationRequest, Failure> {
    subscribe(on: DispatchQueue.global(qos: .userInitiated))
      .asyncMap { request in
        guard request.flags.isPaywallPresented else {
          return request
        }
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Paywall Already Presented",
          info: ["message": "Superwall.shared.isPaywallPresented is true"]
        )
        let error = InternalPresentationLogic.presentationError(
          domain: "SWPresentationError",
          code: 102,
          title: "Paywall Already Presented",
          value: "You can only present one paywall at a time."
        )
        let state: PaywallState = .presentationError(error)
        paywallStatePublisher.send(state)
        paywallStatePublisher.send(completion: .finished)
        throw PresentationPipelineError.paywallAlreadyPresented
      }
      .eraseToAnyPublisher()
  }
}
