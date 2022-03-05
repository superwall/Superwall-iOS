import UIKit
import Foundation
import StoreKit
import TPInAppReceipt
import GameController

/// `Paywall` is the primary class for integrating Superwall into your application. To learn more, read our iOS getting started guide: https://docs.superwall.me/docs/ios
public final class Paywall: NSObject {
  // MARK: - Public Properties
  /// The object that acts as the delegate of Paywall.
	@objc public static var delegate: PaywallDelegate?

  /// WARNING: Only use this enum to set `Paywall.networkEnvironment` if told so explicitly by the Superwall team.
  public enum PaywallNetworkEnvironment {
    /// Default: Use the standard latest environment
    case release
    /// WARNING: Use a release candidate environment
    case releaseCandidate
    /// WARNING: Use the nightly build environment
    case developer
  }

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

  // MARK: - Private Properties
  /// Used as the reload function if a paywall takes to long to load. set in paywall.present
	static var presentAgain = {}
	static var shared = Paywall(apiKey: nil)
	static var isFreeTrialAvailableOverride: Bool?

	var presentingWindow: UIWindow?
  var productsById: [String: SKProduct] = [:]
	var didTryToAutoRestore = false
  var eventsTrackedBeforeConfigWasFetched: [EventData] = []
	var paywallWasPresentedThisSession = false
	var lastAppClose: Date?
	var didTrackLaunch = false
	var didFetchConfig = !Store.shared.triggers.isEmpty

	var paywallViewController: SWPaywallViewController? {
		return PaywallManager.shared.presentedViewController
	}

	var recentlyPresented = false {
		didSet {
			if recentlyPresented {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(700)) {
          self.recentlyPresented = false
        }
			}
		}
	}

	var isPaywallPresented: Bool {
		return paywallViewController != nil
	}

  // MARK: - Public Functions
	/// Configures an instance of Superwall's Paywall SDK with a specified API key. If you don't pass through a userId, we'll create one for you. Calling `Paywall.identify(userId: String)` in the future will automatically alias these two for simple reporting.
	///  - Parameter apiKey: Your Public API Key from: https://superwall.me/applications/1/settings/keys
	///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
	@discardableResult
	@objc public static func configure(
    apiKey: String,
    userId: String? = nil,
    delegate: PaywallDelegate? = nil
  ) -> Paywall {
		shared = Paywall(
      apiKey: apiKey,
      userId: userId,
      delegate: delegate
    )
		return shared
	}

	/// Links your userId to Superwall's automatically generated Alias. Call this as soon as you have a userId.
	///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
	@discardableResult
	@objc public static func identify(userId: String) -> Paywall {
    // refetch the paywall, we don't know if the alias was for an existing user
    if Store.shared.userId != userId {
			PaywallManager.shared.clearCache()
		}
    Store.shared.appUserId = userId

		return shared
	}

	/// Resets the userId stored by Superwall. Call this when your user signs out.
	@discardableResult
	@objc public static func reset() -> Paywall {
    guard Store.shared.appUserId != nil else {
      return shared
    }

    Store.shared.clear()
    PaywallManager.shared.clearCache()
    shared.fetchConfiguration()

    return shared
	}

	/// Call this in Gamepad's `valueChanged` function to forward game controller events to the paywall via `paywall.js`
	public static func gamepadValueChanged(
    gamepad: GCExtendedGamepad,
    element: GCControllerElement
  ) {
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
		PaywallManager.shared.getPaywallViewController(
      withIdentifier: identifier,
      event: nil,
      cached: true,
      completion: nil
    )
	}

  // MARK: - Private Functions
	private init(
    apiKey: String?,
    userId: String? = nil,
    delegate: PaywallDelegate? = nil
  ) {
		super.init()
		guard let apiKey = apiKey else {
			return
		}
    Store.shared.configure(
      appUserId: userId,
      apiKey: apiKey
    )

    Self.delegate = delegate
    SKPaymentQueue.default().add(self)
		addActiveStateObservers()
		fetchConfiguration()
	}

  deinit {
    removeActiveStateObservers()
  }

  private func removeActiveStateObservers() {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  private func addActiveStateObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func applicationWillResignActive() {
    Paywall.track(.appClose)
    lastAppClose = Date()
  }

  @objc private func applicationDidBecomeActive() {
    Paywall.track(.appOpen)

    let twoMinsAgo = 120.0
    let lastAppClose = -(lastAppClose?.timeIntervalSinceNow ?? 0)

    if lastAppClose > twoMinsAgo {
      Paywall.track(.sessionStart)
    }

    if !didTrackLaunch {
      Paywall.track(.appLaunch)
      didTrackLaunch = true
    }

    Store.shared.recordFirstSeenTracked()
  }

	private func fetchConfiguration() {
		Network.shared.config { [weak self] result in
      switch result {
      case .success(let config):
        Store.shared.addConfig(config)
        self?.didFetchConfig = true
        config.cache()
        self?.eventsTrackedBeforeConfigWasFetched.forEach { self?.handleTrigger(forEvent: $0) }
        self?.eventsTrackedBeforeConfigWasFetched.removeAll()
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .paywallCore,
          message: "Failed to Fetch Configuration",
          info: nil,
          error: error
        )
        self?.didFetchConfig = true
      }
		}
	}

	func handleTrigger(forEvent event: EventData) {
		onMain { [weak self] in
			guard let self = self else {
        return
      }
      guard self.didFetchConfig else {
        return self.eventsTrackedBeforeConfigWasFetched.append(event)
      }

      let canTriggerPaywall = PaywallLogic.canTriggerPaywall(
        eventName: event.name,
        triggers: Store.shared.triggers,
        isPaywallPresented: self.isPaywallPresented
      )

      if canTriggerPaywall {
        // delay in case they are presenting a view controller alongside an event they are calling
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
          Paywall.internallyPresent(fromEvent: event)
        }
      } else {
        Logger.debug(
          logLevel: .warn,
          scope: .paywallCore,
          message: "Event Used as Trigger",
          info: ["message": "You can't use events as triggers"],
          error: nil
        )
      }
		}
	}
}

// MARK: - SWPaywallViewControllerDelegate
extension Paywall: SWPaywallViewControllerDelegate {
	func eventDidOccur(
    paywallViewController: SWPaywallViewController,
    result: PaywallPresentationResult
  ) {
		// TODO: log this
		onMain { [weak self] in
			switch result {
			case .closed:
        self?.dismiss(
          paywallViewController,
          state: .closed
        )
			case .initiatePurchase(let productId):
				guard let product = StoreKitManager.shared.productsById[productId] else {
          return
        }
				paywallViewController.loadingState = .loadingPurchase
				Paywall.delegate?.purchase(product: product)
			case .initiateRestore:
				Paywall.shared.tryToRestore(
          paywallViewController,
          userInitiated: true
        )
			case .openedURL(let url):
				Paywall.delegate?.willOpenURL?(url: url)
			case .openedDeepLink(let url):
				Paywall.delegate?.willOpenDeepLink?(url: url)
			case .custom(let string):
				Paywall.delegate?.handleCustomPaywallAction?(withName: string)
			}
		}
	}
}
