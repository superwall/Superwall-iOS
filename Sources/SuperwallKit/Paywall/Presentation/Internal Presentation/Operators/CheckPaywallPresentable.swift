//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//
// swiftlint:disable strict_fileprivate

import UIKit
import Combine

struct PresentablePipelineOutput {
  let debugInfo: [String: Any]
  let paywallViewController: PaywallViewController
  let presenter: UIViewController
  let confirmableAssignment: ConfirmableAssignment?
}

extension Superwall {
  /// Checks conditions for whether the paywall can present before accessing a window on
  /// which the paywall can present.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  @discardableResult
  func checkPaywallIsPresentable(
    input: PaywallVcPipelineOutput,
    request: PresentationRequest,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil
  ) async throws -> PresentablePipelineOutput {
    let subscriptionStatus = await request.flags.subscriptionStatus.async()
    if await InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: subscriptionStatus == .active,
      overrides: .init(
        isDebuggerLaunched: request.flags.isDebuggerLaunched,
        shouldIgnoreSubscriptionStatus: request.paywallOverrides?.ignoreSubscriptionStatus,
        presentationCondition: input.paywallViewController.paywall.presentation.condition
      )
    ) {
      let state: PaywallState = .skipped(.userIsSubscribed)
      paywallStatePublisher?.send(state)
      paywallStatePublisher?.send(completion: .finished)
      throw PresentationPipelineError.userIsSubscribed
    }

    // Return early with stub if we're just getting the paywall result.
    if request.flags.type == .getPresentationResult ||
      request.flags.type == .getImplicitPresentationResult {
      return await PresentablePipelineOutput(
        debugInfo: input.debugInfo,
        paywallViewController: input.paywallViewController,
        presenter: UIViewController(),
        confirmableAssignment: input.confirmableAssignment
      )
    }

    if request.presenter == nil {
      await createPresentingWindowIfNeeded()
    }

    // Make sure there's a presenter. If there isn't throw an error if no paywall is being presented
    let providedViewController = request.presenter
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
      let state: PaywallState = .presentationError(error)
      paywallStatePublisher?.send(state)
      paywallStatePublisher?.send(completion: .finished)
      throw PresentationPipelineError.noPresenter
    }

    let sessionEventsManager = dependencyContainer.sessionEventsManager
    await sessionEventsManager?.triggerSession.activateSession(
      for: request.presentationInfo,
      on: request.presenter,
      paywall: input.paywallViewController.paywall,
      triggerResult: input.triggerResult
    )

    return PresentablePipelineOutput(
      debugInfo: input.debugInfo,
      paywallViewController: input.paywallViewController,
      presenter: presenter,
      confirmableAssignment: input.confirmableAssignment
    )
  }

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
    presentationItems.window = presentingWindow
  }

  @MainActor
  func destroyPresentingWindow() {
    presentationItems.window = nil
  }
}
