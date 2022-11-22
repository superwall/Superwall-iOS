//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//
// swiftlint:disable strict_fileprivate

import UIKit
import Combine

struct PresentablePipelineOutput {
  let request: PresentationRequest
  let debugInfo: DebugInfo
  let paywallViewController: PaywallViewController
  let presenter: UIViewController
}

// TODO: Check whether the errors thrown here are passed back to the state publisher

extension AnyPublisher where Output == PaywallVcPipelineOutput, Failure == Error {
  /// Checks conditions for whether the paywall can present before accessing a window on
  /// which the paywall can present.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func checkPaywallIsPresentable(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PresentablePipelineOutput, Error> {
    asyncMap { input in
      if await InternalPresentationLogic.shouldNotPresentPaywall(
        isUserSubscribed: Superwall.shared.isUserSubscribed,
        isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
        shouldIgnoreSubscriptionStatus: input.request.paywallOverrides?.ignoreSubscriptionStatus,
        presentationCondition: input.paywallViewController.paywall.presentation.condition
      ) {
        throw PresentationPipelineError.cancelled
      }

      await SessionEventsManager.shared.triggerSession.activateSession(
        for: input.request.presentationInfo,
        on: input.request.presentingViewController,
        paywall: input.paywallViewController.paywall,
        triggerResult: input.triggerResult
      )

      if input.request.presentingViewController == nil {
        await Superwall.shared.createPresentingWindowIfNeeded()
      }

      // Make sure there's a presenter. If there isn't throw an error if no paywall is being presented
      let providedViewController = input.request.presentingViewController
      let rootViewController = await Superwall.shared.presentingWindow?.rootViewController

      guard let presenter = (providedViewController ?? rootViewController) else {
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "No Presentor to Present Paywall",
          info: input.debugInfo,
          error: nil
        )
        if await !Superwall.shared.isPaywallPresented {
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

      return PresentablePipelineOutput(
        request: input.request,
        debugInfo: input.debugInfo,
        paywallViewController: input.paywallViewController,
        presenter: presenter
      )
    }
    .eraseToAnyPublisher()
  }
}

extension Superwall {
  @MainActor
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

  func destroyPresentingWindow() {
    presentingWindow?.isHidden = true
    presentingWindow = nil
  }
}
