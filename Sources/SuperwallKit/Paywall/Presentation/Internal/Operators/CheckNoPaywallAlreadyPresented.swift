//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Throws an error if the paywall is already presented.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  func checkNoPaywallAlreadyPresented(
    _ request: PresentationRequest,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async throws {
    guard request.flags.isPaywallPresented else {
      return
    }
    Logger.debug(
      logLevel: .error,
      scope: .paywallPresentation,
      message: "Paywall Already Presented",
      info: ["message": "Superwall.shared.isPaywallPresented is true"]
    )
    let error = InternalPresentationLogic.presentationError(
      domain: "SWKPresentationError",
      code: 102,
      title: "Paywall Already Presented",
      value: "You can only present one paywall at a time."
    )
    let state: PaywallState = .presentationError(error)
    paywallStatePublisher.send(state)
    paywallStatePublisher.send(completion: .finished)
    throw PresentationPipelineError.paywallAlreadyPresented
  }
}
