import Foundation
import StoreKit
import Combine

/// The primary class for integrating Superwall into your application. It provides access to all its featured via static functions and variables.
public final class Superwall: NSObject {
  // MARK: - Public Properties
  /// The delegate of the Paywall instance. The delegate is responsible for handling callbacks from the SDK in response to certain events that happen on the paywall.
  @objc public static var delegate: SuperwallDelegate?

  /// Properties stored about the user, set using ``Superwall/Superwall/setUserAttributes(_:)``.
  public static var userAttributes: [String: Any] {
    return shared.identityManager.userAttributes
  }

  /// The presented paywall view controller.
  @MainActor
  public static var presentedViewController: UIViewController? {
    return PaywallManager.shared.presentedViewController
  }

  /// A convenience variable to access and change the paywall options that you passed to ``configure(apiKey:delegate:options:)``.
  public static var options: SuperwallOptions {
    return shared.configManager.options
  }

  /// The ``PaywallInfo`` object of the most recently presented view controller.
  @MainActor
  public static var latestPaywallInfo: PaywallInfo? {
    let presentedPaywallInfo = PaywallManager.shared.presentedViewController?.paywallInfo
    return presentedPaywallInfo ?? shared.latestDismissedPaywallInfo
  }
  /// The current user's id.
  ///
  /// If you haven't called ``Superwall/Superwall/logIn(userId:)`` or ``Superwall/Superwall/createAccount(userId:)``,
  /// this value will return an anonymous user id which is cached to disk
  public static var userId: String {
    return IdentityManager.shared.userId
  }

  // MARK: - Internal Properties
  /// The ``PaywallInfo`` object stored from the latest paywall that was dismissed.
  var latestDismissedPaywallInfo: PaywallInfo?

  /// Used as the reload function if a paywall takes to long to load. set in paywall.present
  static var shared = Superwall(apiKey: nil)

  /// Used as a strong reference to any track function that doesn't directly return a publisher.
  static var trackCancellable: AnyCancellable?

  /// The publisher from the last paywall presentation.
  var presentationPublisher: AnyCancellable?

  /// The request that triggered the last successful paywall presentation.
  var lastSuccessfulPresentationRequest: PresentationRequest?

  /// The window that presents the paywall.
  var presentingWindow: UIWindow?

  /// Determines whether a product restoration has automatically occurred
  /// after a transaction error.
  var didTryToAutoRestore = false

  /// Determines whether a paywall has been presented in the session.
  var paywallWasPresentedThisSession = false

  /// The presented paywall view controller.
  @MainActor
  var paywallViewController: PaywallViewController? {
    return PaywallManager.shared.presentedViewController
  }

  /// Determines whether a paywall is being presented.
  @MainActor
  var isPaywallPresented: Bool {
    return paywallViewController != nil
  }

  /// Determines whether the user has an active subscription. Performed on the main thread.
  var isUserSubscribed: Bool {
    // Prevents deadlock when calling from main thread
    if Thread.isMainThread {
      return Superwall.delegate?.isUserSubscribed() ?? false
    }

    var isSubscribed = false

    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()

    onMain {
      isSubscribed = Superwall.delegate?.isUserSubscribed() ?? false
      dispatchGroup.leave()
    }

    dispatchGroup.wait()
    return isSubscribed
  }

  /// The config manager.
  var configManager: ConfigManager = .shared

  /// The identity manager.
  var identityManager: IdentityManager = .shared

  // MARK: - Private Functions
  private override init() {}

  private init(
    apiKey: String?,
    delegate: SuperwallDelegate? = nil,
    options: SuperwallOptions? = nil
  ) {
    super.init()
    guard let apiKey = apiKey else {
      return
    }
    Storage.shared.configure(apiKey: apiKey)

    // Initialise session events manager and app session manager on main thread
    _ = SessionEventsManager.shared
    _ = AppSessionManager.shared

    if delegate != nil {
      Self.delegate = delegate
    }

    SKPaymentQueue.default().add(self)
    Storage.shared.recordAppInstall()
    Task {
      await configManager.fetchConfiguration(withOptions: options)
      await identityManager.configure()
    }
  }

  // MARK: - Public Functions
  /// Configures a shared instance of ``Superwall/Superwall`` for use throughout your app.
  ///
  /// Call this as soon as your app finishes launching in `application(_:didFinishLaunchingWithOptions:)`. For a tutorial on the best practices for implementing the delegate, we recommend checking out our <doc:GettingStarted> article.
  /// - Parameters:
  ///   - apiKey: Your Public API Key that you can get from the Superwall dashboard settings. If you don't have an account, you can [sign up for free](https://superwall.com/sign-up).
  ///   - delegate: A class that conforms to ``SuperwallDelegate``. The delegate methods receive callbacks from the SDK in response to certain events on the paywall.
  ///   - options: A ``SuperwallOptions`` object which allows you to customise the appearance and behavior of the paywall.
  /// - Returns: The newly configured ``Superwall/Superwall`` instance.
  @discardableResult
  @objc public static func configure(
    apiKey: String,
    delegate: SuperwallDelegate? = nil,
    options: SuperwallOptions? = nil
  ) -> Superwall {
    guard Storage.shared.apiKey.isEmpty else {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Superwall.configure called multiple times. Please make sure you only call this once on app launch."
      )
      return shared
    }
    shared = Superwall(
      apiKey: apiKey,
      delegate: delegate,
      options: options
    )
    return shared
  }

  /// Preloads all paywalls that the user may see based on campaigns and triggers turned on in your Superwall dashboard.
  ///
  /// To use this, first set ``PaywallOptions/shouldPreload``  to `false` when configuring the SDK. Then call this function when you would like preloading to begin.
  ///
  /// Note: This will not reload any paywalls you've already preloaded via ``Superwall/Superwall/preloadPaywalls(forTriggers:)``.
  @objc public static func preloadAllPaywalls() {
    Task {
      await shared.configManager.preloadAllPaywalls()
    }
  }

  /// Preloads paywalls for specific event names.
  ///
  /// To use this, first set ``PaywallOptions/shouldPreload``  to `false` when configuring the SDK. Then call this function when you would like preloading to begin.
  ///
  /// Note: This will not reload any paywalls you've already preloaded.
  @objc public static func preloadPaywalls(forEvents eventNames: Set<String>) {
    Task {
      await shared.configManager.preloadPaywalls(for: eventNames)
    }
  }
}

extension Superwall {
	// TODO: create debugger manager class

	/// Overrides the default device locale for testing purposes.
  ///
  /// You can also preview your paywall in different locales using the in-app debugger. See <doc:InAppPreviews> for more.
	///  - Parameter localeIdentifier: The locale identifier for the language you would like to test.
	public static func localizationOverride(localeIdentifier: String? = nil) {
		LocalizationManager.shared.selectedLocale = localeIdentifier
	}

  /// Attemps to implicitly trigger a paywall for a given analytical event.
  ///
  ///  - Parameters:
  ///     - event: The data of an analytical event data that could trigger a paywall.
  @MainActor
  func handleImplicitTrigger(forEvent event: EventData) async {
    await IdentityManager.hasIdentity.async()

    let presentationInfo: PresentationInfo = .implicitTrigger(event)

    let outcome = SuperwallLogic.canTriggerPaywall(
      eventName: event.name,
      triggers: Set(configManager.triggersByEventName.keys),
      isPaywallPresented: isPaywallPresented
    )

    switch outcome {
    case .deepLinkTrigger:
      if isPaywallPresented {
        await Superwall.dismiss()
      }
      let presentationRequest = PresentationRequest(presentationInfo: presentationInfo)
      await Superwall.shared.internallyPresent(presentationRequest)
        .asyncNoValue()
    case .triggerPaywall:
      // delay in case they are presenting a view controller alongside an event they are calling
      let twoHundredMilliseconds = UInt64(200_000_000)
      try? await Task.sleep(nanoseconds: twoHundredMilliseconds)
      let presentationRequest = PresentationRequest(presentationInfo: presentationInfo)
      await Superwall.shared.internallyPresent(presentationRequest)
        .asyncNoValue()
    case .disallowedEventAsTrigger:
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Event Used as Trigger",
        info: ["message": "You can't use events as triggers"],
        error: nil
      )
    case .dontTriggerPaywall:
      return
    }
	}
}

// MARK: - PaywallViewControllerDelegate
extension Superwall: PaywallViewControllerDelegate {
  @MainActor
  func eventDidOccur(
    _ paywallEvent: PaywallWebEvent,
    on paywallViewController: PaywallViewController
  ) async {
    // TODO: log this
    switch paywallEvent {
    case .closed:
      self.dismiss(
        paywallViewController,
        state: .closed
      )
    case .initiatePurchase(let productId):
      guard let product = StoreKitManager.shared.productsById[productId] else {
        return
      }
      paywallViewController.loadingState = .loadingPurchase
      Superwall.delegate?.purchase(product: product)
    case .initiateRestore:
      await tryToRestore(
        paywallViewController,
        userInitiated: true
      )
    case .openedURL(let url):
      Superwall.delegate?.willOpenURL?(url: url)
    case .openedUrlInSafari(let url):
      Superwall.delegate?.willOpenURL?(url: url)
    case .openedDeepLink(let url):
      Superwall.delegate?.willOpenDeepLink?(url: url)
    case .custom(let string):
      Superwall.delegate?.handleCustomPaywallAction?(withName: string)
    }
  }
}
