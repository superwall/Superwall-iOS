//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Cancels the state publisher if the user is already subscribed unless the trigger result is ``TriggerResult/paywall(_:)``.
  /// This is because a paywall can be presented to a user regardless of subscription status.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - triggerResult: The trigger result.
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  func checkUserSubscription(
    request: PresentationRequest,
    triggerResult: TriggerResult,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>
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
