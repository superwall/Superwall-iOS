//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/11/2022.
//

import Combine

extension AnyPublisher where Output == PaywallVcPipelineOutput, Failure == Error {
  /// Checks whether the paywall can present based on whether the user is subscribed, ignoring status of debugger.
  func checkPaywallIsPresentable() -> AnyPublisher<TriggerResult, Error> {
    asyncMap { input in
      let subscriptionStatus = await input.request.flags.userSubscriptionStatus.async()
      if await InternalPresentationLogic.userSubscribedAndNotOverridden(
        isUserSubscribed: subscriptionStatus == .active,
        overrides: .init(
          isDebuggerLaunched: false,
          shouldIgnoreSubscriptionStatus: input.request.paywallOverrides?.ignoreSubscriptionStatus,
          presentationCondition: input.paywallViewController.paywall.presentation.condition
        )
      ) {
        throw GetTrackResultError.userIsSubscribed
      }
      return input.triggerResult
    }
    .eraseToAnyPublisher()
  }
}
