import UIKit
import Foundation
import StoreKit
import TPInAppReceipt
import GameController


// MARK: Types

extension Paywall {
	
	/// Completion block that is optionally passed through `Paywall.present()`. Gets called if an error occurs while presenting a Superwall paywall, or if all paywalls are set to off in your dashboard. It's a good idea to add your legacy paywall presentation logic here just in case :)
	internal typealias FallbackBlock = () -> ()
	
	/// WARNING: Only use this enum to set `Paywall.networkEnvironment` if told so explicitly by the Superwall team.
	public enum PaywallNetworkEnvironment {
		/// Default: Use the standard latest environment
		case release
		/// WARNING: Use a release candidate environment
		case releaseCandidate
		/// WARNING: Use the nightly build environment
		case developer
	}
}


/// `Paywall` is the primary class for integrating Superwall into your application. To learn more, read our iOS getting started guide: https://docs.superwall.me/docs/ios
public class Paywall: NSObject {
	
	
	
	
	
	
	// -----------------------
	// MARK: Public Properties
	// -----------------------
	
	
	
	
	
	
	/// The object that acts as the delegate of Paywall.
	@objc public static var delegate: PaywallDelegate? = nil
	
	/// WARNING: Determines which network environment your SDK should use. Defaults to latest. You should under no circumstance change this unless you received the go-ahead from the Superwall team.
	public static var networkEnvironment: PaywallNetworkEnvironment = .release
	
	/// Defines the `title` of the alert presented to the end user when restoring transactions fails. Defaults to `No Subscription Found`
	public static var restoreFailedTitleString = "No Subscription Found"
	
	/// Defines the `message` of the alert presented to the end user when restoring transactions fails. Defaults to `We couldn't find an active subscription for your account.`
	public static var restoreFailedMessageString = "We couldn't find an active subscription for your account."
	
	/// Defines the `close button title` of the alert presented to the end user when restoring transactions fails. Defaults to `Okay`
	public static var restoreFailedCloseButtonString = "Okay"
	
	/// Set this to `true` to forward events from the Game Controller to the Paywall via `Paywall.gamepadValueChanged(gamepad:element:)`
	public static var isGameControllerEnabled = false
	
	/// Set this to `false` to globally disable paywall presentation animations (passed  to `paywallPresentor.present(animated:)`) `
	public static var shouldAnimatePaywallPresentation = true
	
	/// Set this to `false` to globally disable paywall dismissal animations (passed  to `paywallVC.dismiss(animated:)`) `
	public static var shouldAnimatePaywallDismissal = true
	
	/// Set this to `true` to pre-load and cache triggers (and all associated paywalls / products) upon initializing the SDK instead of loading and caching triggers in a just-in-time fashion. Defaults to `true`
	public static var shouldPreloadTriggers = true
	
	/// Prints logs to the console if set to `true`. Default is `false`
	@objc public static var debugMode = false
	
	/// Defines the minimum log level to print to the console. Defaults to nil (none)
	public static var logLevel: LogLevel? = .debug {
		didSet {
			debugMode = logLevel != nil
		}
	}
	
	/// Defines the scope of logs to print to the console. Defaults to .all
	public static var logScopes: Set<LogScope> = [.all] {
		didSet {
			debugMode = !logScopes.isEmpty
		}
	}
	
	/// Access properties stored on the user
	public static var userAttributes: [String: Any] {
		return Store.shared.userAttributes
	}
	
	
	// ------------------------
	// MARK: Private Properties
	// ------------------------
	
	
	
	
	
	
	internal static var presentAgain = {} // Used as the reload function if a paywall takes to long to load. set in paywall.present
	internal static var shared: Paywall = Paywall(apiKey: nil)
	internal static var isFreeTrialAvailableOverride: Bool? = nil
	
	internal var presentingWindow: UIWindow? = nil
	internal var triggerPaywallResponseIsLoading = Set<String>() // used to keep track of which triggers are loading paywalls, so we don't do it 100 times
	internal var productsById: [String: SKProduct] = [String: SKProduct]()
	internal var didTryToAutoRestore = false
	internal var didAddPaymentQueueObserver = false
	internal var eventsTrackedBeforeConfigWasFetched = [EventData]()
	internal var paywallWasPresentedThisSession = false
	internal var lastAppClose: Date? = nil
	internal var didTrackLaunch = false
	internal var didFetchConfig = !Store.shared.triggers.isEmpty
	
	internal var paywallViewController: SWPaywallViewController? {
		return PaywallManager.shared.presentedViewController
	}
	
	internal var recentlyPresented: Bool = false {
		didSet {
			if recentlyPresented {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: {
					self.recentlyPresented = false
				})
			}
		}
	}
	
	private var apiKey: String? {
		return Store.shared.apiKey
	}
	private var appUserId: String? {
		return Store.shared.appUserId
	}
	private var aliasId: String? {
		return Store.shared.aliasId
	}
	
	internal var isPaywallPresented: Bool {
		return self.paywallViewController != nil
	}
	
	
	
	
	
	
	// ----------------------
	// MARK: Public Functions
	// ----------------------
	
	
	
	
	
	
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
			PaywallManager.shared.clearCache()
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
			PaywallManager.shared.clearCache()
			shared.fetchConfiguration()
			
			if !Store.shared.didTrackFirstSeen {
				Paywall.track(.firstSeen)
				Store.shared.recordFirstSeenTracked()
			}
		}
		
		return shared
	}
	
	/// Call this in Gamepad's `valueChanged` function to forward game controller events to the paywall via `paywall.js`
	public static func gamepadValueChanged(gamepad: GCExtendedGamepad, element: GCControllerElement) {
		GameControllerManager.shared.gamepadValueChanged(gamepad: gamepad, element: element)
	}
	
	// TODO: create debugger manager class
	

	
	/// Overrides the default device locale for testing purposes. You can also use the in app debugger by scanning a QR code inside of a paywall
	///  - Parameter localeIdentifier: The locale identifier for the language you would like to test
	public static func localizationOverride(localeIdentifier: String? = nil) {
		LocalizationManager.shared.selectedLocale = localeIdentifier
	}
	
	/// Use this to preload a paywall before presenting it. Only necessary if you are manually specifying which paywall to present later — Superwall automatically does this otherwise.
	///  - Parameter identifier: The identifier of the paywall you would like to load in the background, as found in your paywall's settings in the dashboard.
	@objc public static func load(identifier: String) {
		PaywallManager.shared.viewController(identifier: identifier, event: nil, cached: true, completion: nil)
	}
	
	
	// -----------------------
	// MARK: Private Functions
	// -----------------------
	
	
	
	
	
	
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
		
		self.addActiveStateObservers()
		
		fetchConfiguration()
	}
	
	private func fetchConfiguration() {
		Network.shared.config { [weak self] (result) in

			switch(result) {
				case .success(let config):
					Store.shared.add(config: config)
					self?.didFetchConfig = true
					config.cache()
					config.executePostback()
					self?.eventsTrackedBeforeConfigWasFetched.forEach { self?.handleTrigger(forEvent: $0) }
					self?.eventsTrackedBeforeConfigWasFetched.removeAll()
				case .failure(let error):
					Logger.debug(logLevel: .error, scope: .paywallCore, message: "Failed to Fetch Configuration", info: nil, error: error)
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
	
	internal func canTriggerPaywall(event: EventData) -> Bool {
		
        if (Store.shared.triggers.contains(event.name) || Store.shared.v2Triggers.keys.contains(event.name)) && !isPaywallPresented {

			let name = event.name
			let allowedInternalEvents = Set(["app_install", "session_start", "app_launch"])
			guard (allowedInternalEvents.contains(name) || InternalEventName(rawValue: name) == nil) else {
				Logger.debug(logLevel: .warn, scope: .paywallCore, message: "Internal Event Used as Trigger", info: ["message": "You can't use internal events as triggers"], error: nil)
				return false
			}
			
			return true
			
		}
		
		return false
	}
	
	internal func handleTrigger(forEvent event: EventData) {
		
		OnMain { [weak self] in
			
			guard let self = self else { return }
		
			if !self.didFetchConfig {
				self.eventsTrackedBeforeConfigWasFetched.append(event)
			} else {
				
				if self.canTriggerPaywall(event: event) {
					// delay in case they are presenting a view controller alongside an event they are calling
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
						Paywall.present(fromEvent: event)
					})
				}
			
			}
		}
	}
    
    deinit {
        removeActiveStateObservers()
    }
    
}


extension Paywall {
	
	func removeActiveStateObservers() {
		NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
	}
	
	func addActiveStateObservers() {
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
	}
	
	@objc func applicationWillResignActive(_ sender: AnyObject? = nil) {
		Paywall.track(.appClose)
		lastAppClose = Date()
	}
	
	@objc func applicationDidBecomeActive(_ sender: AnyObject? = nil) {
		Paywall.track(.appOpen)
		
		if (Date().timeIntervalSince1970 - (lastAppClose?.timeIntervalSince1970 ?? 0) > 120.0) {
			Paywall.track(.sessionStart)
		}
		
		if !didTrackLaunch {
			Paywall.track(.appLaunch)
			didTrackLaunch = true
		}
		
		if !Store.shared.didTrackFirstSeen {
			Paywall.track(.firstSeen)
			Store.shared.recordFirstSeenTracked()
		}
		
	}
}

extension Paywall: SWPaywallViewControllerDelegate {
	internal func eventDidOccur(paywallViewController: SWPaywallViewController, result: PaywallPresentationResult) {
		
		// TODO: log this
		
//		if let pvc = self.paywallViewController {
//			assert(paywallViewController == pvc)
//		}
		
		OnMain { [weak self] in
			switch result {
			case .closed:
				self?._dismiss(paywallViewController: paywallViewController, userDidPurchase: false)
			case .initiatePurchase(let productId):
				guard let product = StoreKitManager.shared.productsById[productId] else { return }
				paywallViewController.loadingState = .loadingPurchase
				Paywall.delegate?.purchase(product: product)
			case .initiateRestore:
				Paywall.shared.tryToRestore(paywallViewController: paywallViewController, userInitiated: true)
			case .openedURL(let url):
				Paywall.delegate?.willOpenURL?(url: url)
			case .openedDeepLink(let url):
				Paywall.delegate?.willOpenDeepLink?(url: url)
			case .custom(let string):
				Paywall.delegate?.handleCustomPaywallAction?(withName: string)
			}
		}
	}
    
    
	
//	internal func paywallEventDidOccur(result: PaywallPresentationResult) {
//		OnMain { [weak self] in
//			switch result {
//			case .closed:
//				self?._dismiss(userDidPurchase: false)
//			case .initiatePurchase(let productId):
//				// TODO: make sure this can NEVER happen
//					guard let product = StoreKitManager.shared.productsById[productId] else { return }
//				self?.paywallViewController?.loadingState = .loadingPurchase
//				Paywall.delegate?.purchase(product: product)
//			case .initiateRestore:
//				Paywall.shared.tryToRestore(userInitiated: true)
//			case .openedURL(let url):
//				Paywall.delegate?.willOpenURL?(url: url)
//			case .openedDeepLink(let url):
//				Paywall.delegate?.willOpenDeepLink?(url: url)
//			case .custom(let string):
//				Paywall.delegate?.handleCustomPaywallAction?(withName: string)
//			}
//		}
//	}
}
