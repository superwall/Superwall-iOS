//
//  File.swift
//  
//
//  Created by Jake Mor on 4/28/23.
//

import UIKit
import Combine

extension AnyPublisher where Output == PaywallVcPipelineOutput, Failure == Error {
  /// Checks conditions for whether the paywall can present before accessing a window on
  /// which the paywall can present.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func checkSubscriptionStatus(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> PresentablePipelineOutputPublisher {
    asyncMap { input in
      let subscriptionStatus = await input.request.flags.subscriptionStatus.async()
      if await InternalPresentationLogic.userSubscribedAndNotOverridden(
        isUserSubscribed: subscriptionStatus == .active,
        overrides: .init(
          isDebuggerLaunched: input.request.flags.isDebuggerLaunched,
          shouldIgnoreSubscriptionStatus: input.request.paywallOverrides?.ignoreSubscriptionStatus,
          presentationCondition: input.paywallViewController.paywall.presentation.condition
        )
      ) {
        let state: PaywallState = .skipped(.userIsSubscribed)
        paywallStatePublisher.send(state)
        paywallStatePublisher.send(completion: .finished)
        throw PresentationPipelineError.userIsSubscribed
      }

      let sessionEventsManager = input.request.dependencyContainer.sessionEventsManager
      await sessionEventsManager?.triggerSession.activateSession(
        for: input.request.presentationInfo,
        on: input.request.presenter,
        paywall: input.paywallViewController.paywall,
        triggerResult: input.triggerResult
      )

      return await PresentablePipelineOutput(
        request: input.request,
        debugInfo: input.debugInfo,
        paywallViewController: input.paywallViewController,
        presenter: UIViewController(), // TODO: Fix this
        confirmableAssignment: input.confirmableAssignment
      )
    }
    .eraseToAnyPublisher()
  }
}
