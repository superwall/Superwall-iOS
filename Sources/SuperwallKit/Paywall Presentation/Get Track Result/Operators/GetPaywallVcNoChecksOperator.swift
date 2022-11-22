//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/11/2022.
//

import Combine

extension AnyPublisher where Output == TriggerResultResponsePipelineOutput, Failure == Error {
  /// Gets the paywall view controller without checking for obstacles that may prevent it
  /// from showing when an event is tracked.
  func getPaywallViewControllerNoChecks() -> AnyPublisher<PaywallVcPipelineOutput, Error> {
    asyncMap { input in
      let responseIdentifiers = ResponseIdentifiers(
        paywallId: input.experiment.variant.paywallId,
        experiment: input.experiment
      )
      let paywallRequest = PaywallRequest(
        eventData: input.request.presentationInfo.eventData,
        responseIdentifiers: responseIdentifiers,
        overrides: .init(
          products: input.request.paywallOverrides?.products,
          isFreeTrial: input.request.presentationInfo.freeTrialOverride
        )
      )

      do {
        let paywallViewController = try await PaywallManager.shared.getPaywallViewController(
          from: paywallRequest,
          cached: input.request.cached
        )

        let output = PaywallVcPipelineOutput(
          request: input.request,
          triggerResult: input.triggerResult,
          debugInfo: input.debugInfo,
          paywallViewController: paywallViewController
        )
        return output
      } catch {
        throw GetTrackResultError.paywallNotAvailable
      }
    }
    .eraseToAnyPublisher()
  }
}
