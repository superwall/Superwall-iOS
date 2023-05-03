//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//
// swiftlint:disable strict_fileprivate function_body_length

import UIKit
import Combine

struct PresentablePipelineOutput {
  let request: PresentationRequest
  let debugInfo: DebugInfo
  let paywallViewController: PaywallViewController
  let presenter: UIViewController
  let confirmableAssignment: ConfirmableAssignment?
}

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
        Task.detached(priority: .utility) {
          let trackedEvent = InternalSuperwallEvent.UnableToPresent(
            state: .userIsSubscribed
          )
          await Superwall.shared.track(trackedEvent)
        }
        let state: PaywallState = .skipped(.userIsSubscribed)
        paywallStatePublisher.send(state)
        paywallStatePublisher.send(completion: .finished)
        throw PresentationPipelineError.userIsSubscribed
      }

      if input.request.presenter == nil {
        await Superwall.shared.createPresentingWindowIfNeeded()
      }

      // Make sure there's a presenter. If there isn't throw an error if no paywall is being presented
      let providedViewController = input.request.presenter
      let rootViewController = await Superwall.shared.presentationItems.window?.rootViewController

      guard let presenter = (providedViewController ?? rootViewController) else {
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "No Presenter To Present Paywall",
          info: input.debugInfo,
          error: nil
        )

        let error = InternalPresentationLogic.presentationError(
          domain: "SWPresentationError",
          code: 103,
          title: "No UIViewController to present paywall on",
          value: "This usually happens when you call this method before a window was made key and visible."
        )
        Task.detached(priority: .utility) {
          let trackedEvent = InternalSuperwallEvent.UnableToPresent(state: .noPresenter)
          await Superwall.shared.track(trackedEvent)
        }
        let state: PaywallState = .presentationError(error)
        paywallStatePublisher.send(state)
        paywallStatePublisher.send(completion: .finished)
        throw PresentationPipelineError.noPresenter
      }

      let sessionEventsManager = input.request.dependencyContainer.sessionEventsManager
      await sessionEventsManager?.triggerSession.activateSession(
        for: input.request.presentationInfo,
        on: input.request.presenter,
        paywall: input.paywallViewController.paywall,
        triggerResult: input.triggerResult
      )

      return PresentablePipelineOutput(
        request: input.request,
        debugInfo: input.debugInfo,
        paywallViewController: input.paywallViewController,
        presenter: presenter,
        confirmableAssignment: input.confirmableAssignment
      )
    }
    .eraseToAnyPublisher()
  }
}

extension Superwall {
  @MainActor
  fileprivate func createPresentingWindowIfNeeded() {
    guard presentationItems.window == nil else {
      return
    }
    let activeWindow = UIApplication.shared.activeWindow
    var presentingWindow: UIWindow?

    if let windowScene = activeWindow?.windowScene {
      presentingWindow = UIWindow(windowScene: windowScene)
    }

    presentingWindow?.rootViewController = UIViewController()
    presentingWindow?.makeKeyAndVisible()

    presentationItems.window = presentingWindow
  }

  @MainActor
  func destroyPresentingWindow() {
    presentationItems.window = nil
  }
}
