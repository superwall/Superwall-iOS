//
//  File.swift
//  
//
//  Created by Jake Mor on 10/9/21.
//

import Foundation
import UIKit

extension Paywall {
//	@available(*, deprecated, message: "use present(on viewController: UIViewController? = nil, presentationCompletion: (()->())? = nil, dismissalCompletion: DismissalCompletionBlock? = nil, fallback: FallbackBlock? = nil) instead")
//	@objc public static func present(on viewController: UIViewController? = nil,
//									 cached: Bool = true,
//									 presentationCompletion: (()->())? = nil,
//									 purchaseCompletion: ((Bool) -> ())? = nil,
//									 fallback: (()->())? = nil) {
//		present(on: viewController, presentationCompletion: { _  in
//			presentationCompletion?()}, dismissalCompletion: { didPurchase, _, _ in
//				purchaseCompletion?(didPurchase)
//			}, fallback: { _ in
//			fallback?()
//		})
//	}
	
	/// Presents a paywall to the user.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc public static func present(onPresent: ((PaywallInfo?)->())? = nil,
									 onDismiss: ((Bool, String?, PaywallInfo?) -> ())? = nil,
									 onFail: ((NSError?)->())? = nil)  {
		_present(identifier: nil, on: nil, fromEvent: nil, cached: true, onPresent: onPresent, onDismiss: onDismiss, onFail: onFail)
		
	}
	
	
	/// Presents a paywall to the user.
	///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc public static func present(on viewController: UIViewController? = nil,
									 onPresent: ((PaywallInfo?)->())? = nil,
									 onDismiss: ((Bool, String?, PaywallInfo?) -> ())? = nil,
									 onFail: ((NSError?)->())? = nil)  {
		_present(identifier: nil, on: viewController, fromEvent: nil, cached: true, onPresent: onPresent, onDismiss: onDismiss, onFail: onFail)
		
	}
	
	
	/// Presents a paywall to the user.
	///  - Parameter identifier: The identifier of the paywall you wish to present
	///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc public static func present(identifier: String? = nil,
									 on viewController: UIViewController? = nil,
									 onPresent: ((PaywallInfo?)->())? = nil,
									 onDismiss: ((Bool, String?, PaywallInfo?) -> ())? = nil,
									 onFail: ((NSError?)->())? = nil)  {
		

		_present(identifier: identifier, on: viewController, fromEvent: nil, cached: true, onPresent: onPresent, onDismiss: onDismiss, onFail: onFail)
	}
	
	
	/// This function is equivalent to logging an event, but exposes completion blocks in case you would like to execute code based on specific outcomes
	///  - Parameter event: The name of the event you wish to trigger (equivalent to event name in `Paywall.track()`)
	///  - Parameter params: Parameters you wish to pass along to the trigger (equivalent to params in `Paywall.track()`)
	///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onSkip: A completion block that gets called when the paywall's presentation is skipped, either because the trigger is disabled or an error has occurred. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc public static func trigger(event: String? = nil,
									 params: [String: Any]? = nil,
									 on viewController: UIViewController? = nil,
									 onSkip: ((NSError?)->())? = nil,
									 onPresent: ((PaywallInfo?)->())? = nil,
									 onDismiss: ((Bool, String?, PaywallInfo?) -> ())? = nil)  {
		
		var e: EventData? = nil
		
		if let name = event {
			e = Paywall._track(name, [:], params ?? [:], handleTrigger: false)
		}
		
		_present(identifier: nil, on: viewController, fromEvent: e, cached: true, onPresent: onPresent, onDismiss: onDismiss, onFail: onSkip)
	}
	
	
	internal static func _present(identifier: String? = nil,
								  on viewController: UIViewController? = nil,
								  fromEvent: EventData? = nil,
								  cached: Bool = true,
								  onPresent: ((PaywallInfo?)->())? = nil,
								  onDismiss: ((Bool, String?, PaywallInfo?) -> ())? = nil,
								  onFail: ((NSError?)->())? = nil)  {
		
		present(identifier: identifier, on: viewController, fromEvent: fromEvent, cached: cached, presentationCompletion: onPresent, dismissalCompletion: onDismiss, fallback: onFail)
		
	}
	
	internal static func present(identifier: String? = nil,
									on viewController: UIViewController? = nil,
									fromEvent: EventData? = nil,
									cached: Bool = true,
									presentationCompletion: ((PaywallInfo?)->())? = nil,
									dismissalCompletion: ((Bool, String?, PaywallInfo?) -> ())? = nil,
									fallback: ((NSError?) -> ())? = nil) {
		
		
		if isDebuggerLaunched {
			// if the debugger is launched, ensure the viewcontroller is the debugger
			guard viewController is SWDebugViewController else { return }
		} else {
			// otherwise, ensure we should present the paywall via the delegate method
			guard !(delegate?.isUserSubscribed() ?? false) else { return }
		}
		
		self.dismissalCompletion = dismissalCompletion
				
		guard let delegate = delegate else {
			Logger.superwallDebug(string: "Yikes ... you need to set Paywall.delegate before doing anything fancy")
			fallback?(Paywall.shared.presentationError(domain: "SWDelegateError", code: 100, title: "Paywall delegate not set", value: "You need to set Paywall.delegate before doing anything fancy"))
			return
		}
		
		let presentationBlock: ((SWPaywallViewController) -> ()) = { vc in
			
			let presentingWindowExists = shared.presentingWindow != nil
			let alreadyPresented = vc.presentingViewController != nil || vc.isBeingPresented || presentingWindowExists
			
			if viewController == nil && !alreadyPresented {
				shared.createPresentingWindow()
			}
			
			guard let presentor = (viewController ?? shared.presentingWindow?.rootViewController) else {
				Logger.superwallDebug(string: "No UIViewController to present paywall on. This usually happens when you call Paywall.present(on: nil) immediately after calling Paywall.present(on: someViewController)")
				if !alreadyPresented {
					fallback?(Paywall.shared.presentationError(domain: "SWPresentationError", code: 101, title: "No UIViewController to present paywall on", value: "This usually happens when you call this method before a window was made key and visible."))
				}
				return
			}
			
			// if the top most view controller is a paywall view controller
			// the paywall view controller to present has a presenting view controller
			// the paywall view controller to present is in the process of being presented
			
			let isPresented = (presentor as? SWPaywallViewController) != nil || vc.presentingViewController != nil || vc.isBeingPresented || presentingWindowExists
			
			if !isPresented {
				shared.paywallViewController?.readyForEventTracking = false
				vc.willMove(toParent: nil)
				vc.view.removeFromSuperview()
				vc.removeFromParent()
				vc.view.alpha = 1.0
				vc.view.transform = .identity
				vc.webview.scrollView.contentOffset = CGPoint.zero
				delegate.willPresentPaywall?()
								
				presentor.present(vc, animated: true, completion: {
					self.presentAgain = {
						Paywall.set(response: nil, completion: nil)
						present(on: presentor, fromEvent: fromEvent, cached: false, presentationCompletion: presentationCompletion, dismissalCompletion: dismissalCompletion, fallback: fallback)
					}
					delegate.didPresentPaywall?()
					presentationCompletion?(vc._paywallResponse?.paywallInfo)
					
					if let i = vc._paywallResponse?.paywallInfo {
						Paywall.track(.paywallOpen(paywallInfo: i))
					}
					
					shared.paywallViewController?.readyForEventTracking = true
					if (Paywall.isGameControllerEnabled) {
						GameControllerManager.shared.delegate = vc
					}
				})
			} else {
				Logger.superwallDebug(string: "Note: A Paywall is already being presented")
			}

		}
		
		if let vc = shared.paywallViewController, cached, (fromEvent?.name ?? identifier) == lastEventTrigger {
			presentationBlock(vc)
			return
		}

		lastEventTrigger = (fromEvent?.name ?? identifier)
				
		
		PaywallResponseManager.shared.getResponse(identifier: identifier, event: fromEvent) { r, e in
			
			if let r = r {
				
				// if there's a paywall being presented, don't do anything
				if let vc = shared.paywallViewController, vc.presentingViewController != nil || vc.isBeingPresented || shared.presentingWindow != nil || shared.isPresenting {
					Logger.superwallDebug(string: "Note: A Paywall is already being presented, skipping setting a new one.")
					return
				}
				
				// disable immediately subsequent responses from overwritting this one
				shared.isPresenting = true
				
				Paywall.set(response: r) { success in
					if (success) {
						
						guard let vc = shared.paywallViewController else {
							lastEventTrigger = nil
							Logger.superwallDebug(string: "Paywall's viewcontroller is nil!")
							fallback?(Paywall.shared.presentationError(domain: "SWInternalError", code: 102, title: "Paywall not set", value: "Paywall.paywallViewController was nil"))
							return
						}
						
						guard let _ = shared.paywallResponse else {
							lastEventTrigger = nil
							Logger.superwallDebug(string: "Paywall presented before API response was received")
							fallback?(Paywall.shared.presentationError(domain: "SWInternalError", code: 103, title: "Paywall Presented to Early", value: "Paywall presented before API response was received"))
							return
						}
						
						presentationBlock(vc)
						
					} else {
						lastEventTrigger = nil
						fallback?(e)
					}
				}
			} else {
				lastEventTrigger = nil
				fallback?(e)
			}

		}
		
	}
	
	
	func presentationError(domain: String, code: Int, title: String, value: String) -> NSError {
		let userInfo: [String : Any] = [
			NSLocalizedDescriptionKey :  NSLocalizedString(title, value: value, comment: "") ,
		]
		return NSError(domain: domain, code: code, userInfo: userInfo)
	}
	
}



