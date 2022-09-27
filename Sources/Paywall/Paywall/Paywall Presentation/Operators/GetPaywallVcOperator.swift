//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//

import UIKit
import Combine

typealias PaywallVcPipelineData = (
  request: PaywallPresentationRequest,
  triggerOutcome: TriggerResultOutcome,
  debugInfo: DebugInfo,
  paywallViewController: SWPaywallViewController
)

extension AnyPublisher where Output == TriggerOutcomeResponsePipelineData, Failure == Error {
  func getPaywallViewController(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PaywallVcPipelineData, Error> {
    self
      .flatMap { presentationRequest, triggerOutcome, debugInfo, responseIdentifiers in
        Future { promise in
          Task {
            let isDebuggerLaunched = await SWDebugManager.shared.isDebuggerLaunched
            let responseRequest = PaywallResponseRequest(
              eventData: presentationRequest.presentationInfo.eventData,
              responseIdentifiers: responseIdentifiers,
              substituteProducts: presentationRequest.paywallOverrides?.products
            )

            do {
              let paywallViewController = try await PaywallManager.shared.getPaywallViewController(
                from: responseRequest,
                cached: presentationRequest.cached && !isDebuggerLaunched
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

              promise(.success((presentationRequest, triggerOutcome, debugInfo, paywallViewController)))
            } catch {
              if await InternalPresentationLogic.shouldNotDisplayPaywall(
                isUserSubscribed: Paywall.shared.isUserSubscribed,
                isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
                shouldIgnoreSubscriptionStatus: presentationRequest.paywallOverrides?.ignoreSubscriptionStatus
              ) {
                promise(.failure(PresentationPipelineError.cancelled))
              }

              Logger.debug(
                logLevel: .error,
                scope: .paywallPresentation,
                message: "Error Getting Paywall View Controller",
                info: debugInfo,
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

