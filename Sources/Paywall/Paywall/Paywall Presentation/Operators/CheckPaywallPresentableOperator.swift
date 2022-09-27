//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//

import UIKit
import Combine

typealias PresentablePipelineData = (
  request: PaywallPresentationRequest,
  debugInfo: DebugInfo,
  paywallViewController: SWPaywallViewController,
  presenter: UIViewController
)

extension AnyPublisher where Output == PaywallVcPipelineData, Failure == Error {
  func checkPaywallIsPresentable(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PresentablePipelineData, Error> {
    self
      .flatMap { request, triggerOutcome, debugInfo, paywallViewController in
        Future {
          try await MainActor.run {
            if InternalPresentationLogic.shouldNotDisplayPaywall(
              isUserSubscribed: Paywall.shared.isUserSubscribed,
              isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
              shouldIgnoreSubscriptionStatus: request.paywallOverrides?.ignoreSubscriptionStatus,
              presentationCondition: paywallViewController.paywallResponse.presentationCondition
            ) {
              throw PresentationPipelineError.cancelled
            }

            SessionEventsManager.shared.triggerSession.activateSession(
              for: request.presentationInfo,
              on: request.presentingViewController,
              paywallResponse: paywallViewController.paywallResponse,
              triggerResult: triggerOutcome.result
            )

            if request.presentingViewController == nil {
              Paywall.shared.createPresentingWindowIfNeeded()
            }

            // Make sure there's a presenter. If there isn't throw an error if no paywall is being presented
            guard let presenter = (request.presentingViewController ?? Paywall.shared.presentingWindow?.rootViewController) else {
              Logger.debug(
                logLevel: .error,
                scope: .paywallPresentation,
                message: "No Presentor to Present Paywall",
                info: debugInfo,
                error: nil
              )
              if !Paywall.shared.isPaywallPresented {
                let error = InternalPresentationLogic.presentationError(
                  domain: "SWPresentationError",
                  code: 101,
                  title: "No UIViewController to present paywall on",
                  value: "This usually happens when you call this method before a window was made key and visible."
                )
                let state: PaywallState = .skipped(.error(error))
                paywallStatePublisher.send(state)
                paywallStatePublisher.send(completion: .finished)
              }
              throw PresentationPipelineError.cancelled
            }
            return (request, debugInfo, paywallViewController, presenter)
          }
        }
      }
      .eraseToAnyPublisher()
  }
}

extension Paywall {
  fileprivate func createPresentingWindowIfNeeded() {
    guard presentingWindow == nil else {
      return
    }
    let activeWindow = UIApplication.shared.activeWindow

    if let windowScene = activeWindow?.windowScene {
      presentingWindow = UIWindow(windowScene: windowScene)
    }

    presentingWindow?.rootViewController = UIViewController()
    presentingWindow?.windowLevel = .normal
    presentingWindow?.makeKeyAndVisible()
  }
}
