//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/05/2023.
//

import Foundation
import Combine
import UIKit

extension Superwall {
  /// Checks conditions for whether the paywall can present.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - paywall: The ``Paywall`` whose presentation condition is checked.
  ///   - triggerResult: The ``TriggerResult``.
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  func checkSubscriptionStatus(
    request: PresentationRequest,
    paywall: Paywall,
    triggerResult: TriggerResult,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async throws {
    let subscriptionStatus = await request.flags.subscriptionStatus.async()
    if InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: subscriptionStatus == .active,
      overrides: .init(
        isDebuggerLaunched: request.flags.isDebuggerLaunched,
        shouldIgnoreSubscriptionStatus: request.paywallOverrides?.ignoreSubscriptionStatus,
        presentationCondition: paywall.presentation.condition
      )
    ) {
      let state: PaywallState = .skipped(.userIsSubscribed)
      paywallStatePublisher.send(state)
      paywallStatePublisher.send(completion: .finished)
      throw PresentationPipelineError.userIsSubscribed
    }

    let sessionEventsManager = dependencyContainer.sessionEventsManager
    await sessionEventsManager?.triggerSession.activateSession(
      for: request.presentationInfo,
      on: request.presenter,
      paywall: paywall,
      triggerResult: triggerResult
    )
  }
}
