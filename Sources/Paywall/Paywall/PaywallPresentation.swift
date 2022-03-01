//
//  File.swift
//  
//
//  Created by Jake Mor on 10/9/21.
//

import Foundation
import UIKit

extension Paywall {
	/// Dismisses the presented paywall. Doesn't trigger a `PurchaseCompletionBlock` call if provided during `Paywall.present()`, since this action is developer initiated.
	/// - Parameter completion: A completion block of type `(()->())? = nil` that gets called after the paywall is dismissed.
	@objc public static func dismiss(_ completion: (() -> Void)? = nil) {
		if let pwv = shared.paywallViewController {
			shared.dismiss(paywallViewController: pwv, userDidPurchase: false, completion: completion)
		}
	}

	/// Presents a paywall to the user.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc public static func present(
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
		internallyPresent(
      identifier: nil,
      on: nil,
      fromEvent: nil,
      cached: true,
      onPresent: onPresent,
      onDismiss: onDismiss,
      onFail: onFail
    )
	}

	/// Presents a paywall to the user.
	///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc public static func present(
    on viewController: UIViewController? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
		internallyPresent(
      identifier: nil,
      on: viewController,
      fromEvent: nil,
      cached: true,
      onPresent: onPresent,
      onDismiss: onDismiss,
      onFail: onFail
    )
	}

	/// Presents a paywall to the user.
	///  - Parameter identifier: The identifier of the paywall you wish to present
	///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
	///  - Parameter ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc public static func present(
    identifier: String? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
		internallyPresent(
      identifier: identifier,
      on: viewController,
      fromEvent: nil,
      cached: true,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      onPresent: onPresent,
      onDismiss: onDismiss,
      onFail: onFail
    )
	}

	/// This function is equivalent to logging an event, but exposes completion blocks in case you would like to execute code based on specific outcomes
	///  - Parameter event: The name of the event you wish to trigger (equivalent to event name in `Paywall.track()`)
	///  - Parameter params: Parameters you wish to pass along to the trigger (equivalent to params in `Paywall.track()`)
	///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
	///  - Parameter ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onSkip: A completion block that gets called when the paywall's presentation is skipped, either because the trigger is disabled or an error has occurred. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc public static func trigger(
    event: String? = nil,
    params: [String: Any]? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    onSkip: ((NSError?) -> Void)? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil
  ) {
		var eventData: EventData?

		if let name = event {
      eventData = Paywall.track(name, [:], params ?? [:], handleTrigger: false)
		}

		internallyPresent(
      identifier: nil,
      on: viewController,
      fromEvent: eventData,
      cached: true,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      onPresent: onPresent,
      onDismiss: onDismiss,
      onFail: onSkip
    )
	}

  static func internallyPresent(
    identifier: String? = nil,
    on viewController: UIViewController? = nil,
    fromEvent: EventData? = nil,
    cached: Bool = true,
    ignoreSubscriptionStatus: Bool = false,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
		present(
      identifier: identifier,
      on: viewController,
      fromEvent: fromEvent,
      cached: cached,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      presentationCompletion: onPresent,
      dismissalCompletion: onDismiss,
      fallback: onFail
    )
	}

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  static func present(
    identifier: String? = nil,
    on viewController: UIViewController? = nil,
    fromEvent: EventData? = nil,
    cached: Bool = true,
    ignoreSubscriptionStatus: Bool = false,
    presentationCompletion: ((PaywallInfo?) -> Void)? = nil,
    dismissalCompletion: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
    fallback: ((NSError?) -> Void)? = nil
  ) {
    let debugInfo: [String: Any] = [
      "on": viewController.debugDescription,
      "fromEvent": fromEvent.debugDescription,
      "cached": cached,
      "presentationCompletion": presentationCompletion.debugDescription,
      "dismissalCompletion": dismissalCompletion.debugDescription,
      "fallback": fallback.debugDescription
    ]

		Logger.debug(
      logLevel: .debug,
      scope: .paywallPresentation,
      message: "Called Paywall.present",
      info: debugInfo,
      error: nil
    )

		if SWDebugManager.shared.isDebuggerLaunched {
			// if the debugger is launched, ensure the viewcontroller is the debugger
			guard viewController is SWDebugViewController else { return }
		}

		if let delegate = delegate {
			if delegate.isUserSubscribed() && !SWDebugManager.shared.isDebuggerLaunched {
				if !ignoreSubscriptionStatus {
					return
				}
			}
		}

		PaywallManager.shared.viewController(
      identifier: identifier,
      event: fromEvent,
      cached: cached && !SWDebugManager.shared.isDebuggerLaunched
    ) { paywallViewController, error in
			// if there's a paywall being presented, don't do anything
			if Paywall.shared.isPaywallPresented {
				Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Paywall Already Presented",
          info: ["message": "Paywall.shared.isPaywallPresented is true"],
          error: nil
        )
				return
			}

			// check for errors
			if let error = error {
				Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Error Getting Paywall View Controller",
          info: debugInfo,
          error: error
        )
				fallback?(error)
				return
			}

			// make sure there's a vc
			guard let paywallViewController = paywallViewController else {
				Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Paywall View Controller is Nil",
          info: debugInfo,
          error: nil
        )
				fallback?(
          Paywall.shared.presentationError(
            domain: "SWInternalError",
            code: 102,
            title: "Paywall view controller was nil",
            value: "No further errors were propogated"
          )
        )
				return
			}

			if viewController == nil {
        shared.createPresentingWindowIfNeeded()
			}

			// make sure there's a presenter. if there isn't throw an error if no paywall is presented
			guard let presenter = (viewController ?? shared.presentingWindow?.rootViewController) else {
				Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "No Presentor to Present Paywall",
          info: debugInfo,
          error: nil
        )
				if !Paywall.shared.isPaywallPresented {
					fallback?(
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
        dismissalBlock: dismissalCompletion
      ) { success in
				if success {
					self.presentAgain = {
						PaywallManager.shared.removePaywall(identifier: identifier, event: fromEvent)
						present(
              identifier: identifier,
              on: viewController,
              fromEvent: fromEvent,
              cached: false,
              presentationCompletion: presentationCompletion,
              dismissalCompletion: dismissalCompletion,
              fallback: fallback
            )
					}
					presentationCompletion?(paywallViewController.paywallInfo)
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
		}
	}

	func presentationError(domain: String, code: Int, title: String, value: String) -> NSError {
		let userInfo: [String: Any] = [
      NSLocalizedDescriptionKey: NSLocalizedString(title, value: value, comment: "")
		]
		return NSError(domain: domain, code: code, userInfo: userInfo)
	}
}


extension Paywall {
  func dismiss(
    paywallViewController: SWPaywallViewController,
    userDidPurchase: Bool? = nil,
    productId: String? = nil,
    completion: (() -> Void)? = nil
  ) {
		onMain {
			if let userDidPurchase = userDidPurchase,
        let paywallInfo = paywallViewController.paywallInfo {
        paywallViewController.dismiss(
          didPurchase: userDidPurchase,
          productId: productId,
          paywallInfo: paywallInfo
        ) {
          completion?()
        }
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
