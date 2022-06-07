//
//  InternalPaywallPresentation.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import UIKit

extension Paywall {
  // swiftlint:disable:next function_body_length
  static func internallyPresent(
    _ presentationInfo: PresentationInfo,
    on presentingViewController: UIViewController? = nil,
    cached: Bool = true,
    ignoreSubscriptionStatus: Bool = false,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: PaywallDismissalCompletionBlock? = nil,
    onFail: ((NSError) -> Void)? = nil
  ) {
    guard Paywall.shared.didFetchConfig else {
      let trigger = PreConfigTrigger(
        presentationInfo: presentationInfo,
        viewController: presentingViewController,
        ignoreSubscriptionStatus: ignoreSubscriptionStatus,
        onFail: onFail,
        onPresent: onPresent,
        onDismiss: onDismiss
      )
      Storage.shared.cachePreConfigTrigger(trigger)
      return
    }

    let eventData = presentationInfo.eventData
    let debugInfo: [String: Any] = [
      "on": presentingViewController.debugDescription,
      "fromEvent": eventData.debugDescription as Any,
      "cached": cached,
      "presentationCompletion": onPresent.debugDescription,
      "dismissalCompletion": onDismiss.debugDescription,
      "fallback": onFail.debugDescription
    ]

    Logger.debug(
      logLevel: .debug,
      scope: .paywallPresentation,
      message: "Called Paywall.present",
      info: debugInfo
    )

    if SWDebugManager.shared.isDebuggerLaunched {
      // if the debugger is launched, ensure the viewcontroller is the debugger
      guard presentingViewController is SWDebugViewController else {
        return
      }
    }

    if Paywall.shared.isUserSubscribed,
      !SWDebugManager.shared.isDebuggerLaunched,
      !ignoreSubscriptionStatus {
      return
    }

    PaywallManager.shared.getPaywallViewController(
      presentationInfo,
      cached: cached && !SWDebugManager.shared.isDebuggerLaunched
    ) { result in
      // if there's a paywall being presented, don't do anything
      if Paywall.shared.isPaywallPresented {
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Paywall Already Presented",
          info: ["message": "Paywall.shared.isPaywallPresented is true"]
        )
        return
      }

      switch result {
      case .success(let paywallViewController):
        SessionEventsManager.shared.triggerSession.activateSession(
          for: presentationInfo,
          on: presentingViewController,
          paywallResponse: paywallViewController.paywallResponse
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
          if !Paywall.shared.isPaywallPresented {
            onFail?(
              Paywall.shared.presentationError(
                domain: "SWPresentationError",
                code: 101,
                title: "No UIViewController to present paywall on",
                value: "This usually happens when you call this method before a window was made key and visible."
              )
            )
          }
          return
        }

        paywallViewController.present(
          on: presenter,
          presentationInfo: presentationInfo,
          dismissalBlock: onDismiss
        ) { success in
          if success {
            self.presentAgain = {
              if let presentingPaywallIdentifier = paywallViewController.paywallResponse.identifier {
                PaywallManager.shared.removePaywall(withIdentifier: presentingPaywallIdentifier)
              }
              internallyPresent(
                presentationInfo,
                on: presentingViewController,
                cached: false,
                onPresent: onPresent,
                onDismiss: onDismiss,
                onFail: onFail
              )
            }
            onPresent?(paywallViewController.paywallInfo)
          } else {
            Logger.debug(
              logLevel: .info,
              scope: .paywallPresentation,
              message: "Paywall Already Presented",
              info: debugInfo
            )
          }
        }
      case .failure(let error):
        let nsError = error as NSError
        if nsError.code == 4000 || nsError.code == 4001 {
          // NoRuleMatch or Holdout, sending ended session.
          SessionEventsManager.shared.triggerSession.activateSession(
            for: presentationInfo,
            on: presentingViewController
          )
        }

        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Error Getting Paywall View Controller",
          info: debugInfo,
          error: error
        )
        onFail?(error)
      }
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
    state: PaywallDismissalResult.DismissState,
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
      if #available(iOS 13.0, *) {
        let scenes = UIApplication.shared.connectedScenes
        if let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
          presentingWindow = UIWindow(windowScene: windowScene)
        }
      }

      if presentingWindow == nil {
        presentingWindow = UIWindow(frame: UIScreen.main.bounds)
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
