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
  /// This is called by
  ///  ``getPaywall(forEvent:params:paywallOverrides:delegate:)`` instead of
  ///  the `getPresenter` function in the pipeline (because we don't want to get a presenter here).
  ///  
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
    let subscriptionStatus = try await request.flags.subscriptionStatus.throwableAsync()
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
