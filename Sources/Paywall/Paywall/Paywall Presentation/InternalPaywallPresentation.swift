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
    withIdentifier identifier: String? = nil,
    on presentingViewController: UIViewController? = nil,
    fromEvent: EventData? = nil,
    cached: Bool = true,
    ignoreSubscriptionStatus: Bool = false,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: PaywallDismissalCompletionBlock? = nil,
    onFail: ((NSError) -> Void)? = nil
  ) {
    let debugInfo: [String: Any] = [
      "on": presentingViewController.debugDescription,
      "fromEvent": fromEvent.debugDescription,
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

    if let delegate = delegate,
      delegate.isUserSubscribed(),
      !SWDebugManager.shared.isDebuggerLaunched,
      !ignoreSubscriptionStatus {
      return
    }

    PaywallManager.shared.getPaywallViewController(
      withIdentifier: identifier,
      event: fromEvent,
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
          fromEventData: fromEvent,
          calledFromIdentifier: identifier != nil,
          dismissalBlock: onDismiss
        ) { success in
          if success {
            self.presentAgain = {
              PaywallManager.shared.removePaywall(withIdentifier: identifier, forEvent: fromEvent)
              internallyPresent(
                withIdentifier: identifier,
                on: presentingViewController,
                fromEvent: fromEvent,
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
              info: debugInfo,
              error: nil
            )
          }
        }
      case .failure(let error):
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
      guard let paywallInfo = paywallViewController.paywallInfo else {
        return
      }
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

  func createPresentingWindowIfNeeded() {
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
