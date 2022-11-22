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
  let triggerResult: TriggerResult
  let debugInfo: DebugInfo
  let paywallViewController: PaywallViewController
}

extension AnyPublisher where Output == TriggerResultResponsePipelineOutput, Failure == Error {
  /// Requests the paywall view controller to present. If an error occurred during this,
  /// or a paywall is already presented, it cancels the pipeline and sends an `error`
  /// state to the paywall state publisher.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func getPaywallViewController(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PaywallVcPipelineOutput, Error> {
    asyncMap { input in
      let isDebuggerLaunched = await SWDebugManager.shared.isDebuggerLaunched
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
          triggerResult: input.triggerResult,
          debugInfo: input.debugInfo,
          paywallViewController: paywallViewController
        )
        return output
      } catch {
        if await InternalPresentationLogic.shouldNotPresentPaywall(
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
