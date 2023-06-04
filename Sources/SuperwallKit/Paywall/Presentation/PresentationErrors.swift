//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/06/2023.
//

import Foundation
import Combine

// Errors that can be thrown within any of the
// presentation pipelines.
extension Superwall {
  func userIsSubscribed(
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>?
  ) -> PresentationPipelineError {
    let state: PaywallState = .skipped(.userIsSubscribed)
    paywallStatePublisher?.send(state)
    paywallStatePublisher?.send(completion: .finished)
    return PresentationPipelineError.userIsSubscribed
  }
}
