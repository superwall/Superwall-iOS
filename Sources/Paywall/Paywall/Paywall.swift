import UIKit
import Foundation
import StoreKit
import GameController

/// The primary class for integrating Superwall into your application. It provides access to all its featured via static functions and variables.
public final class Paywall: NSObject {
  // MARK: - Public Properties
  /// The delegate of the Paywall instance. The delegate is responsible for handling callbacks from the SDK in response to certain events that happen on the paywall.
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

	/// Set this to `false` to load and cache triggers in a just-in-time fashion.
  ///
  /// This defaults to `true`. This pre-loads and caches triggers and their associated paywalls and products upon initialization of the SDK.
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
		return Storage.shared.userAttributes
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
	var didFetchConfig = !Storage.shared.triggers.isEmpty

	var paywallViewController: SWPaywallViewController? {
		return PaywallManager.shared.presentedViewController
	}

	var recentlyPresented = false {
		didSet {
      guard recentlyPresented else {
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(700)) {
        self.recentlyPresented = false
      }
		}
	}

	var isPaywallPresented: Bool {
		return paywallViewController != nil
	}

  // MARK: - Public Functions
	/// Configures a shared instance of ``Paywall/Paywall`` for use throughout your app.
  ///
  /// Call this as soon as your app finishes launching in `application(_:didFinishLaunchingWithOptions:)`. For a tutorial on the best practices for implementing the delegate, we recommend checking out our <doc:GettingStarted> article.
	/// - Parameters:
  ///   - apiKey: Your Public API Key that you can get from the Superwall dashboard settings. If you don't have an account, you can [sign up for free](https://superwall.com/sign-up).
	///   - userId: Your user's unique identifier, as defined by your backend system. If you don't specify a `userId`, we'll create one for you. Calling ``Paywall/Paywall/identify(userId:)`` later on will automatically alias these two for simple reporting.
  ///   - delegate: A class that conforms to ``PaywallDelegate``. The delegate methods receive callbacks from the SDK in response to certain events on the paywall.
  /// - Returns: The newly configured ``Paywall/Paywall`` instance.
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

	/// Links your `userId` to Superwall's automatically generated alias. Call this as soon as you have a userId.
	///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Paywall instance.
	@discardableResult
	@objc public static func identify(userId: String) -> Paywall {
    // refetch the paywall, we don't know if the alias was for an existing user
    if Storage.shared.userId != userId {
			PaywallManager.shared.clearCache()
		}
    Storage.shared.appUserId = userId

		return shared
	}

	/// Resets the `userId` stored by Superwall.
  ///
  /// Call this when your user signs out.
	@discardableResult
	@objc public static func reset() -> Paywall {
    guard Storage.shared.appUserId != nil else {
      return shared
    }

    Storage.shared.clear()
    PaywallManager.shared.clearCache()
    shared.fetchConfiguration()

    return shared
	}

	/// Forwards Game controller events to the paywall.
  ///
  /// Call this in Gamepad's `valueChanged` function to forward game controller events to the paywall via `paywall.js`
  ///
  /// See <doc:GameControllerSupport> for more information.
  ///
  /// - Parameters:
  ///   - gamepad: The extended Gamepad controller profile.
  ///   - element: The game controller element.
	public static func gamepadValueChanged(
    gamepad: GCExtendedGamepad,
    element: GCControllerElement
  ) {
		GameControllerManager.shared.gamepadValueChanged(gamepad: gamepad, element: element)
	}

	// TODO: create debugger manager class

	/// Overrides the default device locale for testing purposes.
  ///
  /// You can also preview your paywall in different locales using the in-app debugger. See <doc:InAppPreviews> for more.
	///  - Parameter localeIdentifier: The locale identifier for the language you would like to test.
	public static func localizationOverride(localeIdentifier: String? = nil) {
		LocalizationManager.shared.selectedLocale = localeIdentifier
	}

	/// Preloads a paywall, for use before calling ``Paywall/Paywall/present(identifier:on:ignoreSubscriptionStatus:onPresent:onDismiss:onFail:)``.
  ///
  /// Only call this if you are manually specifying which paywall to present later — Superwall automatically does this otherwise.
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
  private override init() {}

	private init(
    apiKey: String?,
    userId: String? = nil,
    delegate: PaywallDelegate? = nil
  ) {
		super.init()
		guard let apiKey = apiKey else {
			return
		}
    Storage.shared.configure(
      appUserId: userId,
      apiKey: apiKey
    )

    if delegate != nil {
      Self.delegate = delegate
    }

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
    Paywall.track(SuperwallEvent.AppClose())
    lastAppClose = Date()
  }

  @objc private func applicationDidBecomeActive() {
    Paywall.track(SuperwallEvent.AppOpen())

    let sessionDidStart = PaywallLogic.sessionDidStart(lastAppClose)

    if sessionDidStart {
      Paywall.track(SuperwallEvent.SessionStart())
    }

    if !didTrackLaunch {
      Paywall.track(SuperwallEvent.AppLaunch())
      didTrackLaunch = true
    }

    Storage.shared.recordFirstSeenTracked()
  }

	private func fetchConfiguration() {
    Network.shared.getConfig { [weak self] result in
      switch result {
      case .success(let config):
        Storage.shared.addConfig(config)
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

  /// Attemps to trigger a paywall for a given analytical event.
  ///
  ///  - Parameters:
  ///     - event: The data of an analytical event data that could trigger a paywall.
	func handleTrigger(forEvent event: EventData) {
		onMain { [weak self] in
			guard let self = self else {
        return
      }
      guard self.didFetchConfig else {
        return self.eventsTrackedBeforeConfigWasFetched.append(event)
      }

      let outcome = PaywallLogic.canTriggerPaywall(
        eventName: event.name,
        v1Triggers: Storage.shared.triggers,
        v2Triggers: Set(Storage.shared.v2Triggers.keys),
        isPaywallPresented: self.isPaywallPresented
      )

      switch outcome {
      case .triggerPaywall:
        // delay in case they are presenting a view controller alongside an event they are calling
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
          Paywall.internallyPresent(fromEvent: event)
        }
      case .disallowedEventAsTrigger:
        Logger.debug(
          logLevel: .warn,
          scope: .paywallCore,
          message: "Event Used as Trigger",
          info: ["message": "You can't use events as triggers"],
          error: nil
        )
      case .dontTriggerPaywall:
        return
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
