//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//

import UIKit
import Combine

struct PaywallVcPipelineOutput {
  let request: PaywallPresentationRequest
  let triggerOutcome: TriggerResultOutcome
  let debugInfo: DebugInfo
  let paywallViewController: SWPaywallViewController
}

extension AnyPublisher where Output == TriggerOutcomeResponsePipelineOutput, Failure == Error {
  func getPaywallViewController(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PaywallVcPipelineOutput, Error> {
    flatMap { input in
      Future { promise in
        Task {
          let isDebuggerLaunched = await SWDebugManager.shared.isDebuggerLaunched
          let responseRequest = PaywallResponseRequest(
            eventData: input.request.presentationInfo.eventData,
            responseIdentifiers: input.responseIdentifiers,
            substituteProducts: input.request.paywallOverrides?.products
          )

          do {
            let paywallViewController = try await PaywallManager.shared.getPaywallViewController(
              from: responseRequest,
              cached: input.request.cached && !isDebuggerLaunched
            )

            // if there's a paywall being presented, don't do anything
            if await Paywall.shared.isPaywallPresented {
              Logger.debug(
                logLevel: .error,
                scope: .paywallPresentation,
                message: "Paywall Already Presented",
                info: ["message": "Paywall.shared.isPaywallPresented is true"]
              )
              promise(.failure(PresentationPipelineError.cancelled))
            }

            let output = PaywallVcPipelineOutput(
              request: input.request,
              triggerOutcome: input.triggerOutcome,
              debugInfo: input.debugInfo,
              paywallViewController: paywallViewController
            )
            promise(.success(output))
          } catch {
            if await InternalPresentationLogic.shouldNotDisplayPaywall(
              isUserSubscribed: Paywall.shared.isUserSubscribed,
              isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
              shouldIgnoreSubscriptionStatus: input.request.paywallOverrides?.ignoreSubscriptionStatus
            ) {
              promise(.failure(PresentationPipelineError.cancelled))
            }

            Logger.debug(
              logLevel: .error,
              scope: .paywallPresentation,
              message: "Error Getting Paywall View Controller",
              info: input.debugInfo,
              error: error
            )
            paywallStatePublisher.send(.skipped(.error(error)))
            promise(.failure(PresentationPipelineError.cancelled))
          }
        }
      }
    }
    .eraseToAnyPublisher()
  }
}

