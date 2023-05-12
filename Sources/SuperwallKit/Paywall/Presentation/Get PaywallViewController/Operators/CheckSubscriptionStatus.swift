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
  /// Checks conditions for whether the paywall can present before accessing a window on
  /// which the paywall can present.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func checkSubscriptionStatus(
    _ request: PresentationRequest,
    _ input: PaywallVcPipelineOutput,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async throws -> PresentablePipelineOutput {
    let subscriptionStatus = await request.flags.subscriptionStatus.async()
    if await InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: subscriptionStatus == .active,
      overrides: .init(
        isDebuggerLaunched: request.flags.isDebuggerLaunched,
        shouldIgnoreSubscriptionStatus: request.paywallOverrides?.ignoreSubscriptionStatus,
        presentationCondition: input.paywallViewController.paywall.presentation.condition
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
      paywall: input.paywallViewController.paywall,
      triggerResult: input.triggerResult
    )

    return await PresentablePipelineOutput(
      debugInfo: input.debugInfo,
      paywallViewController: input.paywallViewController,
      presenter: UIViewController(), // TODO: Fix this
      confirmableAssignment: input.confirmableAssignment
    )
  }
}
