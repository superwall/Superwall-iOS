//
//  InternalPaywallPresentation.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable function_body_length cyclomatic_complexity

import UIKit
import Combine

/// The reason the paywall presentation was skipped.
public enum PaywallSkippedReason {
  /// The user was assigned to a holdout group.
  case holdout(Experiment)

  /// No rule was matched for this event.
  case noRuleMatch

  /// A trigger was not found for this event.
  ///
  /// Please make sure the trigger is enabled on the dashboard and you have the correct spelling of the event.
  case triggerNotFound

  /// An error occurred.
  case error(Error)
}

extension Paywall {
  static func internallyPresent(
    _ presentationInfo: PresentationInfo,
    on presentingViewController: UIViewController? = nil,
    cached: Bool = true,
    paywallOverrides: PaywallOverrides? = nil,
    paywallState: ((PaywallState) -> Void)? = nil
  ) async {
    await IdentityManager.shared.$hasIdentity.isTrue()

    let eventData = presentationInfo.eventData

    let debugInfo: [String: Any] = [
      "on": presentingViewController.debugDescription,
      "fromEvent": eventData.debugDescription as Any,
      "cached": cached,
      "paywallState": paywallState.debugDescription
    ]
    Logger.debug(
      logLevel: .debug,
      scope: .paywallPresentation,
      message: "Called Paywall.track",
      info: debugInfo
    )

    if await SWDebugManager.shared.isDebuggerLaunched {
      // if the debugger is launched, ensure the viewcontroller is the debugger
      guard presentingViewController is SWDebugViewController else {
        return
      }
    }

    let triggerOutcome = PaywallResponseLogic.getTriggerResultAndConfirmAssignment(
      presentationInfo: presentationInfo,
      triggers: ConfigManager.shared.triggers
    )

    let identifiers: ResponseIdentifiers

    switch triggerOutcome.info {
    case .paywall(let responseIdentifiers):
      identifiers = responseIdentifiers
    case .holdout(let experiment):
      SessionEventsManager.shared.triggerSession.activateSession(
        for: presentationInfo,
        on: presentingViewController,
        triggerResult: triggerOutcome.result
      )
      paywallState?(.skipped(.holdout(experiment)))
      return
    case .noRuleMatch:
      SessionEventsManager.shared.triggerSession.activateSession(
        for: presentationInfo,
        on: presentingViewController,
        triggerResult: triggerOutcome.result
      )
      paywallState?(.skipped(.noRuleMatch))
      return
    case .triggerNotFound:
      paywallState?(.skipped(.triggerNotFound))
      return
    case let .error(error):
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "Error Getting Paywall View Controller",
        info: debugInfo,
        error: error
      )
      paywallState?(.skipped(.error(error)))
      return
    }

    do {
      let isDebuggerLaunched = await SWDebugManager.shared.isDebuggerLaunched
      let paywallViewController = try await PaywallManager.shared.getPaywallViewController(
        from: eventData,
        responseIdentifiers: identifiers,
        substituteProducts: paywallOverrides?.products,
        cached: cached && !isDebuggerLaunched
      )

      // if there's a paywall being presented, don't do anything
      if await shared.isPaywallPresented {
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Paywall Already Presented",
          info: ["message": "Paywall.shared.isPaywallPresented is true"]
        )
        return
      }

      await MainActor.run {
        if InternalPresentationLogic.shouldNotDisplayPaywall(
          isUserSubscribed: shared.isUserSubscribed,
          isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
          shouldIgnoreSubscriptionStatus: paywallOverrides?.ignoreSubscriptionStatus,
          presentationCondition: paywallViewController.paywallResponse.presentationCondition
        ) {
          return
        }

        SessionEventsManager.shared.triggerSession.activateSession(
          for: presentationInfo,
          on: presentingViewController,
          paywallResponse: paywallViewController.paywallResponse,
          triggerResult: triggerOutcome.result
        )

        if presentingViewController == nil {
          shared.createPresentingWindowIfNeeded()
        }

        // Make sure there's a presenter. If there isn't throw an error if no paywall is being presented
        guard let presenter = (presentingViewController ?? shared.presentingWindow?.rootViewController) else {
          Logger.debug(
            logLevel: .error,
            scope: .paywallPresentation,
            message: "No Presentor to Present Paywall",
            info: debugInfo,
            error: nil
          )
          if !shared.isPaywallPresented {
            paywallState?(.skipped(.error(
              shared.presentationError(
                domain: "SWPresentationError",
                code: 101,
                title: "No UIViewController to present paywall on",
                value: "This usually happens when you call this method before a window was made key and visible."
              )
            )))
          }
          return
        }


        paywallViewController.present(
          on: presenter,
          eventData: eventData,
          presentationStyleOverride: paywallOverrides?.presentationStyle,
          paywallState: paywallState
        ) { success in
          if success {
            self.presentAgain = {
              if let presentingPaywallIdentifier = paywallViewController.paywallResponse.identifier {
                PaywallManager.shared.removePaywall(withIdentifier: presentingPaywallIdentifier)
              }
              await internallyPresent(
                presentationInfo,
                on: presentingViewController,
                cached: false,
                paywallOverrides: paywallOverrides,
                paywallState: paywallState
              )
            }
            paywallState?(.presented(paywallViewController.paywallInfo))
          } else {
            Logger.debug(
              logLevel: .info,
              scope: .paywallPresentation,
              message: "Paywall Already Presented",
              info: debugInfo
            )
          }
        }
      }
    } catch {
      if await InternalPresentationLogic.shouldNotDisplayPaywall(
        isUserSubscribed: shared.isUserSubscribed,
        isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
        shouldIgnoreSubscriptionStatus: paywallOverrides?.ignoreSubscriptionStatus
      ) {
        return
      }

      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "Error Getting Paywall View Controller",
        info: debugInfo,
        error: error
      )

      paywallState?(.skipped(.error(error)))
    }
  }

  func presentationError(
    domain: String,
    code: Int,
    title: String,
    value: String
  ) -> NSError {
    let userInfo: [String: Any] = [
      NSLocalizedDescriptionKey: NSLocalizedString(title, value: value, comment: "")
    ]
    return NSError(
      domain: domain,
      code: code,
      userInfo: userInfo
    )
  }

  func dismiss(
    _ paywallViewController: SWPaywallViewController,
    state: PaywallDismissedResult.DismissState,
    completion: (() -> Void)? = nil
  ) {
    onMain {
      let paywallInfo = paywallViewController.paywallInfo
      paywallViewController.dismiss(
        .withResult(
          paywallInfo: paywallInfo,
          state: state
        )
      ) {
        completion?()
      }
    }
  }

  private func createPresentingWindowIfNeeded() {
    if presentingWindow == nil {
      let activeWindow = UIApplication.shared.activeWindow

      if #available(iOS 13.0, *) {
        if let windowScene = activeWindow?.windowScene {
          presentingWindow = UIWindow(windowScene: windowScene)
        }
      } else {
        presentingWindow = UIWindow(frame: activeWindow?.bounds ?? UIScreen.main.bounds)
      }

      presentingWindow?.rootViewController = UIViewController()
      presentingWindow?.windowLevel = .normal
      presentingWindow?.makeKeyAndVisible()
    }
  }

  func destroyPresentingWindow() {
    presentingWindow?.isHidden = true
    presentingWindow = nil
  }
}
