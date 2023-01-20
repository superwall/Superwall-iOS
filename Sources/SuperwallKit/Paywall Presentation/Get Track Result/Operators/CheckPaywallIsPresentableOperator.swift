//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/11/2022.
//

import Combine

extension AnyPublisher where Output == PaywallVcPipelineOutput, Failure == Error {
  /// Checks whether the paywall can present based on pipeline parameters, ignoring status of debugger.
  func checkPaywallIsPresentable() -> AnyPublisher<TriggerResult, Error> {
    asyncMap { input in
      if await InternalPresentationLogic.userSubscribedAndNotOverridden(
        isUserSubscribed: input.request.injections.isUserSubscribed,
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
