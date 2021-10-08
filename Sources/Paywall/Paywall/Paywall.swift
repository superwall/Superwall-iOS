import UIKit
import Foundation
import StoreKit
import TPInAppReceipt
import GameController

/// `Paywall` is the primary class for integrating Superwall into your application. To learn more, read our iOS getting started guide: https://docs.superwall.me/docs/ios
public class Paywall: NSObject {
    
    // MARK: Public
    
    /// Prints debug logs to the console if set to `true`. Default is `false`
    @objc public static var debugMode = false
    
    /// WARNING: Only use this enum to set `Paywall.networkEnvironment` if told so explicitly by the Superwall team.
    public enum PaywallNetworkEnvironment {
        /// Default: Use the standard latest environment
        case release
        /// Use a release candidate environment
        case releaseCandidate
        /// Use the nightly build environment
        case developer
    }
	
	public static func gamepadValueChanged(gamepad: GCExtendedGamepad, element: GCControllerElement) {
		GameControllerManager.shared.gamepadValueChanged(gamepad: gamepad, element: element)
	}
    
    /// WARNING: Determines which network environment your SDK should use. Defaults to latest. You should under no circumstance change this unless you received the go-ahead from the Superwall team.
    public static var networkEnvironment: PaywallNetworkEnvironment = .release
    
    /// The object that acts as the delegate of Paywall. Required implementations include `userDidInitiateCheckout(for product: SKProduct)` and `shouldTryToRestore()`. 
    @objc public static var delegate: PaywallDelegate? = nil
    
    /// Completion block of type `(Bool) -> ()` that is optionally passed through `Paywall.present()`. Gets called when the paywall is dismissed by the user, by way or purchasing, restoring or manually dismissing. Accepts a BOOL that is `true` if the product is purchased or restored, and `false` if the user manually dismisses the paywall.
    /// Please note: This completion is NOT called when  `Paywall.dismiss()` is manually called by the developer.
    public typealias DismissalCompletionBlock = (Bool) -> ()
    
    /// Completion block that is optionally passed through `Paywall.present()`. Gets called if an error occurs while presenting a Superwall paywall, or if all paywalls are set to off in your dashboard. It's a good idea to add your legacy paywall presentation logic here just in case :)
    public typealias FallbackBlock = () -> ()
    
    /// Launches the debugger for you to preview paywalls. If you call `Paywall.track(.deepLinkOpen(deepLinkUrl: url))` from `application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool` in your `AppDelegate`, this funciton is called automatically after scanning your debug QR code in Superwall's web dashboard. Remember to add you URL scheme in settings for this feature to work!
    public static func launchDebugger(toPaywall paywallId: String? = nil) {
        isDebuggerLaunched = true
        Paywall.dismiss(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.618) { // helps if from cold launch
            
            if let vc = UIViewController.topMostViewController {
                
                var dvc: SWDebugViewController? = nil
                var isPresented = false
                
                if vc is SWDebugViewController {
                    dvc = vc as? SWDebugViewController
                    isPresented = true
                } else {
                    dvc = SWDebugViewController()
                }
                
                dvc?.paywallId = paywallId
                
                if let dvc = dvc {
                    
                    if isPresented {
                        dvc.loadPreview()
                    } else {
                        dvc.modalPresentationStyle = .overFullScreen
                        vc.present(dvc, animated: true)
                    }
                }
                
                
            }
        }
    }
    
    internal static func set(response r: PaywallResponse?, completion: ((Bool) -> ())? = nil) {
        
        guard let r = r else {
            self.shared.paywallViewController = nil
            return
        }
        
        shared.paywallResponse = r
        var response = shared.paywallResponse!
        StoreKitManager.shared.get(productsWithIds: response.productIds) { productsById in
            
            var variables = [Variables]()
            
            for p in response.products {
                if let appleProduct = productsById[p.productId] {
                    variables.append(Variables(key: p.product.rawValue, value: appleProduct.eventData))
                    shared.productsById[p.productId] = appleProduct
                    
                    if p.product == .primary {
                        
                        response.isFreeTrialAvailable = appleProduct.hasFreeTrial
                        
                        if let receipt = try? InAppReceipt.localReceipt() {
                            let hasPurchased = receipt.containsPurchase(ofProductIdentifier: p.productId)
                            if hasPurchased && appleProduct.hasFreeTrial {
                                response.isFreeTrialAvailable = false
                            }
                        }
                        
                        // use the override if it is set
                        if let or = isFreeTrialAvailableOverride {
                            response.isFreeTrialAvailable = or
                            isFreeTrialAvailableOverride = nil // reset it for future use
                        }
                    }
                }
            }
            
            response.variables = variables
            
            DispatchQueue.main.async {
                
                shared.paywallViewController = SWPaywallViewController(paywallResponse: response, completion: shared.paywallEventDidOccur)
                
                if let v =  UIApplication.shared.keyWindow?.rootViewController {
                    v.addChild(shared.paywallViewController!)
                    shared.paywallViewController!.view.alpha = 0.01
                    v.view.insertSubview(shared.paywallViewController!.view, at: 0)
                    shared.paywallViewController!.view.transform = CGAffineTransform(translationX: 1000, y: 0)
                    shared.paywallViewController!.didMove(toParent: v)
                }
                
                completion?(true)

            }
            
        }
    }
    
    
    /// DEPRECATED: This method does nothing.
    /// - Parameter completion: DEPRECATED: this will get called with `true` no matter what
	@objc public static func load(completion: ((Bool) -> ())? = nil) {
		completion?(true)
	}
	
	private static func getPaywallResponse(withIdentifier: String? = nil, fromEvent event: EventData? = nil, completion: ((Bool) -> ())? = nil) {
        
		let isFromEvent = event != nil
		let eventName = event?.name ?? "$called_manually"
		
		
		if shared.triggerPaywallResponseIsLoading.contains(eventName) || shared.triggerPaywallResponseIsLoading.contains("$called_manually") {
			return
		}

        Paywall.track(.paywallResponseLoadStart(fromEvent: isFromEvent, event: event))
		
		shared.triggerPaywallResponseIsLoading.removeAll()
		shared.triggerPaywallResponseIsLoading.insert(eventName)
        
		Network.shared.paywall(withIdentifier: withIdentifier, fromEvent: event) { (result) in
            
            switch(result){
            case .success(let response):
					
				if shared.triggerPaywallResponseIsLoading.contains(eventName) {
					
					Paywall.track(.paywallResponseLoadComplete(fromEvent: isFromEvent, event: event))
					Paywall.set(response: response, completion: completion)
					shared.triggerPaywallResponseIsLoading.remove(eventName)
					
				}
                
            case .failure(let error):
				
				if shared.triggerPaywallResponseIsLoading.contains(eventName) {

					Logger.superwallDebug(string: "Failed to load paywall", error: error)
					Paywall.track(.paywallResponseLoadFail(fromEvent: isFromEvent, event: event))
					shared.triggerPaywallResponseIsLoading.remove(eventName)
					DispatchQueue.main.async {
						completion?(false)
					}
				}
            }
            
			
        }
    }
    
    /// Configures an instance of Superwall's Paywall SDK with a specified API key. If you don't pass through a userId, we'll create one for you. Calling `Paywall.identify(userId: String)` in the future will automatically alias these two for simple reporting.
    ///  - Parameter apiKey: Your Public API Key from: https://superwall.me/applications/1/settings/keys
    ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
    @discardableResult
    @objc public static func configure(apiKey: String, userId: String? = nil) -> Paywall {
        shared = Paywall(apiKey: apiKey, userId: userId)
        return shared
    }
    
    /// Links your userId to Superwall's automatically generated Alias. Call this as soon as you have a userId.
    ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
    @discardableResult
    @objc public static func identify(userId: String) -> Paywall {
        
        if Store.shared.userId != userId { // refetch the paywall, we don't know if the alias was for an existing user
            shared.set(appUserID: userId)
            shared.paywallViewController = nil
        } else {
            shared.set(appUserID: userId)
        }
        
        return shared
    }
    
    /// Resets the userId stored by Superwall. Call this when your user signs out.
    @discardableResult
    @objc public static func reset() -> Paywall {
        
        if Store.shared.appUserId != nil {
            Store.shared.clear()
            shared.setAliasIfNeeded()
            shared.paywallViewController = nil
			shared.fetchConfiguration()
			
			if !Store.shared.didTrackFirstSeen {
				Paywall.track(.firstSeen)
				Store.shared.recordFirstSeenTracked()
			}
        }
        
        return shared
    }
    
    /// Dismisses the presented paywall. Doesn't trigger a `PurchaseCompletionBlock` call if provided during `Paywall.present()`, since this action is developer initiated.
    /// - Parameter completion: A completion block of type `(()->())? = nil` that gets called after the paywall is dismissed.
    @objc public static func dismiss(_ completion: (()->())? = nil) {
        shared._dismiss(completion: completion)
    }
        
	@available(*, deprecated, message: "use present(on viewController: UIViewController? = nil, presentationCompletion: (()->())? = nil, dismissalCompletion: DismissalCompletionBlock? = nil, fallback: FallbackBlock? = nil) instead")
    @objc public static func present(on viewController: UIViewController? = nil,
									 cached: Bool = true,
									 presentationCompletion: (()->())? = nil,
									 purchaseCompletion: DismissalCompletionBlock? = nil,
									 fallback: FallbackBlock? = nil) {
		present(on: viewController, presentationCompletion: presentationCompletion, dismissalCompletion: purchaseCompletion, fallback: fallback)
    }
	
	
	
	
	
	
	
	/// Presents a paywall to the user.
	///  - Parameter completion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
	///  - Parameter onDismiss: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.
	///  - Parameter fallback: Gets called when all paywalls are off in the dashboard and the user doesn't have a previously assigned paywall or if an error occurs
	@objc public static func present(completion: ((Bool)->())? = nil,
									 onDismiss: DismissalCompletionBlock? = nil) {
		_present(identifier: nil, on: nil, fromEvent: nil, cached: true, dismissalCompletion: onDismiss, completion: completion)
		
	}
	
	
	
	
	
	
	
	/// Presents a paywall to the user.
	///  - Parameter on: The view controller to present the paywall on. Presents on the `keyWindow`'s `rootViewController` if `nil`. Defaults to `nil`.
	///  - Parameter completion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
	///  - Parameter onDismiss: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.
	///  - Parameter fallback: Gets called when all paywalls are off in the dashboard and the user doesn't have a previously assigned paywall or if an error occurs
	@objc public static func present(on viewController: UIViewController? = nil,
									 completion: ((Bool)->())? = nil,
									 onDismiss: DismissalCompletionBlock? = nil) {
		_present(identifier: nil, on: viewController, fromEvent: nil, cached: true, dismissalCompletion: onDismiss, completion: completion)
		
	}
	
	
	
	
	
	
	
	
	
	/// Presents a paywall to the user.
	///  - Parameter identifier: The identifier of the paywall you wish to present
	///  - Parameter on: The view controller to present the paywall on. Presents on the `keyWindow`'s `rootViewController` if `nil`. Defaults to `nil`.
	///  - Parameter completion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
	///  - Parameter onDismiss: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.
	///  - Parameter fallback: Gets called when all paywalls are off in the dashboard and the user doesn't have a previously assigned paywall or if an error occurs
	@objc public static func present(identifier: String? = nil,
									 on viewController: UIViewController? = nil,
									 completion: ((Bool)->())? = nil,
									 onDismiss: DismissalCompletionBlock? = nil) {
		

		_present(identifier: identifier, on: viewController, fromEvent: nil, cached: true, dismissalCompletion: onDismiss, completion: completion)
	}
	
	
	
	
	
	
	
	/// This function is equivalent to logging an event, but exposes completion blocks in case you would like to execute code based on specific outcomes
	///  - Parameter event: The name of the event you wish to trigger (equivalent to event name in `Paywall.track()`)
	///  - Parameter params: Parameters you wish to pass along to the trigger (equivalent to params in `Paywall.track()`)
	///  - Parameter on: The view controller to present the paywall on. Presents on the `keyWindow`'s `rootViewController` if `nil`. Defaults to `nil`.
	///  - Parameter completion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
	///  - Parameter onDismiss: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.
	///  - Parameter triggerFallback: Gets called if the trigger is not defined, if the trigger is off,  or if an error occurs
	@objc public static func trigger(event: String? = nil,
									 params: [String: Any]? = nil,
									 on viewController: UIViewController? = nil,
									 completion: ((Bool) -> ())? = nil,
									 onDismiss: DismissalCompletionBlock? = nil) {
		
		var e: EventData? = nil
		
		if let name = event {
			e = Paywall._track(name, [:], params ?? [:], handleTrigger: false)
		}
		
		_present(identifier: nil, on: viewController, fromEvent: e, cached: true, dismissalCompletion: onDismiss, completion: completion)
	}
	
	internal static var lastEventTrigger: String? = nil
	
	internal static var presentAgain = {
		
	}
	
	fileprivate static func _present(identifier: String? = nil,
									 on viewController: UIViewController? = nil,
									 fromEvent: EventData? = nil,
									 cached: Bool = true,
									 dismissalCompletion: DismissalCompletionBlock? = nil,
									 completion: ((Bool)->())? = nil) {
		
		present(identifier: identifier, on: viewController, fromEvent: fromEvent, cached: cached, presentationCompletion: {
			completion?(true)
		}, dismissalCompletion: dismissalCompletion, fallback: {
			completion?(false)
		})
		
	}
	
	fileprivate static func present(identifier: String? = nil,
									on viewController: UIViewController? = nil,
									fromEvent: EventData? = nil,
									cached: Bool = true,
									presentationCompletion: (()->())? = nil,
									dismissalCompletion: DismissalCompletionBlock? = nil,
									fallback: FallbackBlock? = nil) {
		
		if isDebuggerLaunched {
			// if the debugger is launched, ensure the viewcontroller is the debugger
			guard viewController is SWDebugViewController else { return }
		} else {
			// otherwise, ensure we should present the paywall via the delegate method
			guard (delegate?.shouldPresentPaywall() ?? false) else { return }
		}
		
		self.dismissalCompletion = dismissalCompletion
		
		let fallbackUsing = fallback ?? fallbackCompletionBlock
		
		guard let delegate = delegate else {
			Logger.superwallDebug(string: "Yikes ... you need to set Paywall.delegate before doing anything fancy")
			fallbackUsing?()
			return
		}
		
		
		let presentationBlock: ((SWPaywallViewController) -> ()) = { vc in
			

			guard let presentor = (viewController ?? UIViewController.topMostViewController) else {
				Logger.superwallDebug(string: "No UIViewController to present paywall on. This usually happens when you call this method before a window was made key and visible. Try calling this a little later, or explicitly pass in a UIViewController to present your Paywall on :)")
				fallbackUsing?()
				return
			}
			
			// if the top most view controller is a paywall view controller
			// the paywall view controller to present has a presenting view controller
			// the paywall view controller to present is in the process of being presented
			
			
			let isPresented = (presentor as? SWPaywallViewController) != nil || vc.presentingViewController != nil || vc.isBeingPresented
			
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
						present(on: viewController, fromEvent: fromEvent, cached: false, presentationCompletion: presentationCompletion, dismissalCompletion: dismissalCompletion, fallback: fallback)
					}
					delegate.didPresentPaywall?()
					presentationCompletion?()
					Paywall.track(.paywallOpen(paywallId: self.shared.paywallId))
					shared.paywallViewController?.readyForEventTracking = true
					if (Paywall.isGameControllerEnabled) {
						GameControllerManager.shared.delegate = vc
					}
				})
			} else {
				Logger.superwallDebug(string: "Note: A Paywall is already being presented")
			}

		}
		
		if let vc = shared.paywallViewController, cached, fromEvent?.name == lastEventTrigger {
			presentationBlock(vc)
			return
		}
		
		lastEventTrigger = fromEvent?.name
		
		getPaywallResponse(withIdentifier: identifier, fromEvent: fromEvent) { success in
			
			if (success) {
				
				guard let vc = shared.paywallViewController else {
					lastEventTrigger = nil
					Logger.superwallDebug(string: "Paywall's viewcontroller is nil!")
					fallbackUsing?()
					return
				}
				
				guard let _ = shared.paywallResponse else {
					lastEventTrigger = nil
					Logger.superwallDebug(string: "Paywall presented before API response was received")
					fallbackUsing?()
					return
				}
				
				presentationBlock(vc)
				
			} else {
				lastEventTrigger = nil
				fallbackUsing?()
			}
		}
	}
    
    
    // MARK: Private
    
    internal static var dismissalCompletion: DismissalCompletionBlock? = nil
    internal static var fallbackCompletionBlock: FallbackBlock? = nil
    
    internal static var shared: Paywall = Paywall(apiKey: nil)
    
    internal static var isFreeTrialAvailableOverride: Bool? = nil
    
    private var apiKey: String? {
        return Store.shared.apiKey
    }
    private var appUserId: String? {
        return Store.shared.appUserId
    }
    private var aliasId: String? {
        return Store.shared.aliasId
    }
	
	// used to keep track of which triggers are loading paywalls, so we don't do it 100 times
	internal var triggerPaywallResponseIsLoading = Set<String>()
    
    internal static var isDebuggerLaunched = false

    private(set) var paywallResponse: PaywallResponse?
    
    private(set) var paywallViewController: SWPaywallViewController?
    
    private(set) var productsById: [String: SKProduct] = [String: SKProduct]()
    
    private var didTryToAutoRestore = false
	
	public static var isGameControllerEnabled = false
    
    private var paywallId: String {
        paywallResponse?.id ?? ""
    }
	
	private var didAddPaymentQueueObserver = false
    
    
    private init(apiKey: String?, userId: String? = nil) {
        
        super.init()
        
        if apiKey == nil {
            return
        }
        
        if let uid = userId {
            self.set(appUserID: uid)
        }

        Store.shared.apiKey = apiKey
        
        setAliasIfNeeded()
        
		if !didAddPaymentQueueObserver {
			SKPaymentQueue.default().add(self)
			didAddPaymentQueueObserver = true
		}
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
		
		fetchConfiguration()
    }
	
	private var didFetchConfig = !Store.shared.triggers.isEmpty
	private var eventsTrackedBeforeConfigWasFetched = [EventData]()
	
	private func fetchConfiguration() {
		Network.shared.config { [weak self] (result) in

			switch(result) {
				case .success(let config):
					Store.shared.add(config: config)
					self?.didFetchConfig = true
					self?.eventsTrackedBeforeConfigWasFetched.forEach { self?.handleTrigger(forEvent: $0) }
					self?.eventsTrackedBeforeConfigWasFetched.removeAll()
					
				case .failure(let error):
					Logger.superwallDebug(string: "Warning: ", error: error)
					self?.didFetchConfig = true
			}

		}
	}
    
    private func setAliasIfNeeded() {
        if Store.shared.aliasId == nil {
            Store.shared.aliasId = "$SuperwallAlias:\(UUID().uuidString)"
            Store.shared.save()
        }
    }

    
    @discardableResult
    private func set(appUserID: String) -> Paywall {
        Store.shared.appUserId = appUserID
        Store.shared.save()
        return self
    }
    

    private func paywallEventDidOccur(result: PaywallPresentationResult) {
        OnMain { [weak self] in
            switch result {
            case .closed:
                self?._dismiss(userDidPurchase: false)
            case .initiatePurchase(let productId):
                // TODO: make sure this can NEVER happen
                guard let product = self?.productsById[productId] else { return }
                self?.paywallViewController?.loadingState = .loadingPurchase
                Paywall.delegate?.userDidInitiateCheckout(for: product)
            case .initiateRestore:
                Paywall.shared.shouldTryToRestore()
            case .openedURL(let url):
                Paywall.delegate?.willOpenURL?(url: url)
            case .openedDeepLink(let url):
                Paywall.delegate?.willOpenDeepLink?(url: url)
            case .custom(let string):
                Paywall.delegate?.didReceiveCustomEvent?(withName: string)
            }
        }
    }
    
    // purchase callbacks
    
    private func _transactionDidBegin(for product: SKProduct) {
        Paywall.track(.transactionStart(paywallId: paywallId, product: product))
        paywallViewController?.loadingState = .loadingPurchase
		
		OnMain { [weak self] in 
			self?.paywallViewController?.showRefreshButtonAfterTimeout(show: false)
		}
		
		
    }

    
    private func _transactionDidSucceed(for product: SKProduct) {
        Paywall.track(.transactionComplete(paywallId: paywallId, product: product))
        
        if let ft = paywallResponse?.isFreeTrialAvailable {
            if ft {
                Paywall.track(.freeTrialStart(paywallId: paywallId, product: product))
            } else {
                Paywall.track(.subscriptionStart(paywallId: paywallId, product: product))
            }
        }
        
        _dismiss(userDidPurchase: true)
    }
	
	internal func handleTrigger(forEvent event: EventData) {
		
		OnMain { [weak self] in
			
			guard let self = self else { return }
		
			if !self.didFetchConfig {
				self.eventsTrackedBeforeConfigWasFetched.append(event)
			} else {
			
				if Store.shared.triggers.contains(event.name) {

					let name = event.name
					
					// ignore if the paywall is already being presented
					
					if let _ = UIViewController.topMostViewController as? SWPaywallViewController {
						return
					}
					
					if let isBeingPresented = self.paywallViewController?.isBeingPresented, isBeingPresented {
						return
					}

					if let _ = self.paywallViewController?.presentingViewController {
						return
					}

					let allowedInternalEvents = Set(["app_install", "app_open", "app_close", "app_launch"])

					// special cases are allowed
					guard (allowedInternalEvents.contains(name) || InternalEventName(rawValue: name) == nil) else {
						Logger.superwallDebug(string: "[Trigger] Warning: We use that event name internally for paywall analytics and you can't use it as a trigger", error: nil)
						return
					}
					
					// delay in case they are presenting a view controller alongside an event they are calling
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
						Paywall.present(fromEvent: event)
					})
					
				}
			}
		}
	}
    
    
    private func _transactionErrorDidOccur(error: SKError?, for product: SKProduct) {
        // prevent a recursive loop
        OnMain { [weak self] in
			
            
            guard let self = self else { return }
			
			self.paywallViewController?.loadingState = .ready
			
            if !self.didTryToAutoRestore {
                Paywall.shared.shouldTryToRestore()
                self.didTryToAutoRestore = true
            } else {
				self.paywallViewController?.loadingState = .ready
                Paywall.track(.transactionFail(paywallId: self.paywallId, product: product, message: error?.localizedDescription ?? ""))
                self.paywallViewController?.presentAlert(title: "Please try again", message: error?.localizedDescription ?? "", actionTitle: "Restore Purchase", action: {
                    Paywall.shared.shouldTryToRestore()
                })
            }
        }
    }
	
	private func shouldTryToRestore() {
		OnMain {
			
			Logger.superwallDebug(string: "attempting restore ...")
			
			if let d = Paywall.delegate {
//				self.paywallViewController?.loadingState = .loadingPurchase
				d.shouldTryToRestore()
			}
			
			
		}
	}
    
    private func _transactionWasAbandoned(for product: SKProduct) {
        Paywall.track(.transactionAbandon(paywallId: paywallId, product: product))
        paywallViewController?.loadingState = .ready
    }
    
    private func _transactionWasRestored() {
        Paywall.track(.transactionRestore(paywallId: paywallId, product: nil))
        _dismiss(userDidPurchase: true)
    }
    
    // if a parent needs to approve the purchase
    private func _transactionWasDeferred() {
        paywallViewController?.presentAlert(title: "Waiting for Approval", message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved.")
        Paywall.track(.transactionFail(paywallId: paywallId, product: nil, message: "Needs parental approval"))
    }
    

    
    private func _dismiss(userDidPurchase: Bool? = nil, completion: (()->())? = nil) {
        OnMain { [weak self] in
            Paywall.delegate?.willDismissPaywall?()
            self?.paywallViewController?.dismiss(animated: true, completion: { [weak self] in
                Paywall.delegate?.didDismissPaywall?()
                self?.paywallViewController?.loadingState = .ready
                completion?()
                if let s = userDidPurchase {
                    Paywall.dismissalCompletion?(s)
                }
                
            })
        }
    }
    
    
    @objc func applicationWillResignActive(_ sender: AnyObject? = nil) {
        Paywall.track(.appClose)
//		Paywall.track(name: "workout_start")
    }
	
	var didTrackLaunch = false
    
    @objc func applicationDidBecomeActive(_ sender: AnyObject? = nil) {
        Paywall.track(.appOpen)
		
		if !didTrackLaunch {
			Paywall.track(.appLaunch)
			didTrackLaunch = true
		}
		
		if !Store.shared.didTrackFirstSeen {
			Paywall.track(.firstSeen)
			Store.shared.recordFirstSeenTracked()
		}
		
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
}



extension Paywall: SKPaymentTransactionObserver {
	
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
			
            guard let product = productsById[transaction.payment.productIdentifier] else { return }
            switch transaction.transactionState {
            case .purchased:
                Logger.superwallDebug(string: "[Transaction Observer] transactionDidSucceed for: \(product.productIdentifier)")
                self._transactionDidSucceed(for: product)
            break
            case .failed:
                if let e = transaction.error as? SKError {
                    var userCancelled = e.code == .paymentCancelled
                    if #available(iOS 12.2, *) {
                        userCancelled = e.code == .overlayCancelled || e.code == .paymentCancelled
                    }

                    if #available(iOS 14.0, *) {
                        userCancelled = e.code == .overlayCancelled || e.code == .paymentCancelled || e.code == .overlayTimeout
                    }

                    if userCancelled {
                        Logger.superwallDebug(string: "[Transaction Observer] transactionWasAbandoned for: \(product.productIdentifier)", error: e)
                        self._transactionWasAbandoned(for: product)
                        return
                    } else {
                        Logger.superwallDebug(string: "[Transaction Observer] transactionErrorDidOccur for: \(product.productIdentifier)", error: e)
                        self._transactionErrorDidOccur(error: e, for: product)
                        return
                    }
				} else {
					self._transactionErrorDidOccur(error: nil, for: product)
					Logger.superwallDebug(string: "[Transaction Observer] transactionErrorDidOccur for: \(product.productIdentifier)", error: transaction.error)
					OnMain { [weak self] in
						self?.paywallViewController?.presentAlert(title: "Something went wrong", message: transaction.error?.localizedDescription ?? "", actionTitle: nil, action: nil)
					}
				}
              
            break
            case .restored:
                Logger.superwallDebug(string: "[Transaction Observer] transactionWasRestored")
                _transactionWasRestored()
            break
            case .deferred:
                Logger.superwallDebug(string: "[Transaction Observer] deferred")
                _transactionWasDeferred()
            case .purchasing:
                Logger.superwallDebug(string: "[Transaction Observer] purchasing")
                _transactionDidBegin(for: product)
            default:
                paywallViewController?.loadingState = .ready
            }
        }
    }
}


internal func OnMain(_ execute: @escaping () -> Void) {
    DispatchQueue.main.async(execute: execute)
}


internal extension UIViewController {
    static var topMostViewController: UIViewController? {
        var presentor: UIViewController? = UIApplication.shared.keyWindow?.rootViewController
        
        while let p = presentor?.presentedViewController {
            presentor = p
        }
        
        return presentor
    }
}

