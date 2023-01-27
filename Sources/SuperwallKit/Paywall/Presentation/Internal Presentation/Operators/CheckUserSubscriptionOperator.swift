//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/12/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == AssignmentPipelineOutput, Failure == Error {
  /// Cancels the pipeline if the user is already subscribed unless the trigger result is `paywall`.
  /// This is because a paywall can be presented to a user regardless of subscription status.
  func checkUserSubscription(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<AssignmentPipelineOutput, Failure> {
    tryMap { input in
      switch input.triggerResult {
      case .paywall:
        return input
      default:
        if input.request.flags.isUserSubscribed {
          Task.detached(priority: .utility) {
            let trackedEvent = InternalSuperwallEvent.UnableToPresent(state: .userIsSubscribed)
            await Superwall.shared.track(trackedEvent)
          }
          paywallStatePublisher.send(.skipped(.userIsSubscribed))
          paywallStatePublisher.send(completion: .finished)
          throw PresentationPipelineError.cancelled
        }
        return input
      }
    }
    .eraseToAnyPublisher()
  }
}
