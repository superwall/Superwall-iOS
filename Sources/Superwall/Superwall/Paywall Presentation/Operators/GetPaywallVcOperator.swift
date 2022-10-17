//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//

import UIKit
import Combine

struct PaywallVcPipelineOutput {
  let request: PresentationRequest
  let triggerOutcome: TriggerResultOutcome
  let debugInfo: DebugInfo
  let paywallViewController: PaywallViewController
}

extension AnyPublisher where Output == TriggerOutcomeResponsePipelineOutput, Failure == Error {
  func getPaywallViewController(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PaywallVcPipelineOutput, Error> {
    asyncMap { input in
      let isDebuggerLaunched = await SWDebugManager.shared.isDebuggerLaunched
      let paywallRequest = PaywallRequest(
        eventData: input.request.presentationInfo.eventData,
        responseIdentifiers: input.responseIdentifiers,
        overrides: .init(
          products: input.request.paywallOverrides?.products,
          isFreeTrial: input.request.presentationInfo.freeTrialOverride
        )
      )

      do {
        let paywallViewController = try await PaywallManager.shared.getPaywallViewController(
          from: paywallRequest,
          cached: input.request.cached && !isDebuggerLaunched
        )

        // if there's a paywall being presented, don't do anything
        if await Superwall.shared.isPaywallPresented {
          Logger.debug(
            logLevel: .error,
            scope: .paywallPresentation,
            message: "Paywall Already Presented",
            info: ["message": "Superwall.shared.isPaywallPresented is true"]
          )
          throw PresentationPipelineError.cancelled
        }

        let output = PaywallVcPipelineOutput(
          request: input.request,
          triggerOutcome: input.triggerOutcome,
          debugInfo: input.debugInfo,
          paywallViewController: paywallViewController
        )
        return output
      } catch {
        if await InternalPresentationLogic.shouldNotDisplayPaywall(
          isUserSubscribed: Superwall.shared.isUserSubscribed,
          isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
          shouldIgnoreSubscriptionStatus: input.request.paywallOverrides?.ignoreSubscriptionStatus
        ) {
          throw PresentationPipelineError.cancelled
        }

        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Error Getting Paywall View Controller",
          info: input.debugInfo,
          error: error
        )
        paywallStatePublisher.send(.skipped(.error(error)))
        throw PresentationPipelineError.cancelled
      }
    }
    .eraseToAnyPublisher()
  }
}
