//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Cancels the pipeline if the user is already subscribed unless the trigger result is `paywall`.
  /// This is because a paywall can be presented to a user regardless of subscription status.
  func checkUserSubscription(
    _ request: PresentationRequest,
    _ triggerResult: TriggerResult,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async throws {
    switch triggerResult {
    case .paywall:
      return
    default:
      let subscriptionStatus = await request.flags.subscriptionStatus.async()
      if subscriptionStatus == .active {
        paywallStatePublisher.send(.skipped(.userIsSubscribed))
        paywallStatePublisher.send(completion: .finished)
        throw PresentationPipelineError.userIsSubscribed
      }
    }
  }
}
