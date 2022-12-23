import Foundation
import StoreKit
import Combine

/// The primary class for integrating Superwall into your application. It provides access to all its featured via static functions and variables.
@objcMembers
public final class Superwall: NSObject, ObservableObject {
  // MARK: - Public Properties
  public static var purchasingDelegate: SuperwallPurchasingDelegate? {
    return shared.dependencyContainer.purchasingDelegateAdapter.swiftDelegate
  }

  /// The optional purchasing delegate of the Superwall instance. By implementing this
  @available(swift, obsoleted: 1.0)
  @objc(purchasingDelegate)
  public static var objcPurchasingDelegate: SuperwallPurchasingDelegateObjc? {
    return shared.dependencyContainer.purchasingDelegateAdapter.objcDelegate
  }

  /// The delegate of the Superwall instance. The delegate is responsible for handling callbacks from the SDK in response to certain events that happen on the paywall.
  public static var delegate: SuperwallDelegate?

  /// Properties stored about the user, set using ``SuperwallKit/Superwall/setUserAttributes(_:)``.
  public static var userAttributes: [String: Any] {
    return shared.dependencyContainer.identityManager.userAttributes
  }

  /// The presented paywall view controller.
  @MainActor
  public static var presentedViewController: UIViewController? {
    return shared.dependencyContainer.paywallManager.presentedViewController
  }

  /// A convenience variable to access and change the paywall options that you passed to ``SuperwallKit/Superwall/configure(apiKey:delegate:options:)-65jyx``.
  public static var options: SuperwallOptions {
    return shared.dependencyContainer.configManager.options
  }

  /// The ``PaywallInfo`` object of the most recently presented view controller.
  @MainActor
  public static var latestPaywallInfo: PaywallInfo? {
    let presentedPaywallInfo = shared.dependencyContainer.paywallManager.presentedViewController?.paywallInfo
    return presentedPaywallInfo ?? shared.presentationItems.paywallInfo
  }

  /// The current user's id.
  ///
  /// If you haven't called ``SuperwallKit/Superwall/logIn(userId:)`` or ``SuperwallKit/Superwall/createAccount(userId:)``,
  /// this value will return an anonymous user id which is cached to disk
  public static var userId: String {
    return shared.dependencyContainer.identityManager.userId
  }

  /// Indicates whether the user is logged in to Superwall.
  ///
  /// If you have previously called ``SuperwallKit/Superwall/logIn(userId:)`` or
  /// ``SuperwallKit/Superwall/createAccount(userId:)``, this will return true.
  ///
  /// - Returns: A boolean indicating whether the user is logged in or not.
  public static var isLoggedIn: Bool {
    return shared.dependencyContainer.identityManager.isLoggedIn
  }

  // TODO: Store value in memory
  // This is kept up to date by the ReceiptManager:
  /// A publisher that indicates whether the user has any active subscription.
  ///
  /// If you're using Combine or SwiftUI, you can subcribe/bind to this to get
  /// notified whenever the user's subscription status changes.
  ///
  /// If you have implemented the ``purchasingDelegate`` then use
  @Published
  public var hasActiveSubscription = false

  /// Returns `true` if Superwall has already been initialized through
  /// ``configure(apiKey:userId:delegate:options:)`` or one of is overloads.
  public static var isConfigured: Bool {
    superwall != nil
  }

  /// The configured shared instance of ``Superwall``.
  ///
  /// - Warning: This method will crash with `fatalError` if ``Superwall`` has
  /// not been initialized through ``configure(apiKey:userId:delegate:options:)``
  /// or one of its overloads. If there's a chance that may have not happened yet, you can use
  /// ``isConfigured`` to check if it's safe to call.
  /// ### Related symbols
  /// - ``isConfigured``
  @objc(sharedSuperwall)
  public static var shared: Superwall {
    guard let superwall = superwall else {
      fatalError("Superwall has not been configured. Please call Superwall.configure()")
    }
    return superwall
  }

  // MARK: - Internal Properties
  private static var superwall: Superwall?

  /// Items involved in the presentation of paywalls.
  var presentationItems = PresentationItems()

  /// The presented paywall view controller.
  @MainActor
  var paywallViewController: PaywallViewController? {
    return dependencyContainer.paywallManager.presentedViewController
  }

  /// Determines whether a paywall is being presented.
  @MainActor
  var isPaywallPresented: Bool {
    return paywallViewController != nil
  }

  /// Handles all dependencies.
  var dependencyContainer: DependencyContainer!

  // MARK: - Private Functions
  private override init() {}

  private init(
    apiKey: String,
    delegate: SuperwallDelegate? = nil,
    swiftPurchasingDelegate: SuperwallPurchasingDelegate? = nil,
    objcPurchasingDelegate: SuperwallPurchasingDelegateObjc? = nil,
    options: SuperwallOptions? = nil
  ) {
    dependencyContainer = DependencyContainer(
      apiKey: apiKey,
      delegate: delegate,
      swiftPurchasingDelegate: swiftPurchasingDelegate,
      objcPurchasingDelegate: objcPurchasingDelegate,
      options: options
    )

    // TODO: Inject here

    

    super.init()

    // This task runs on a background thread, even if called from a main thread.
    // This is because the function isn't marked to run on the main thread,
    // therefore, we don't need to make this detached.
    Task {
      dependencyContainer.storage.configure(apiKey: apiKey)

      Superwall.delegate = delegate

      dependencyContainer.storage.recordAppInstall()

      await dependencyContainer.configManager.fetchConfiguration()
      await dependencyContainer.identityManager.configure()
    }
  }

  /*
   1. Superwall.shared.isSubscribed = A published property that is true if the user has any active subscription.
   3. Superwall.isSubscribed(to: "entitlement") <- Determines whether the user has an active subscription for that level of entitlement.

   TODO: If someone purchases outside of superwall, we need to make sure we are kept in the loop!
   */

  // MARK: - Configuration
  /// Configures a shared instance of ``SuperwallKit/Superwall`` for use throughout your app.
  ///
  /// Call this as soon as your app finishes launching in `application(_:didFinishLaunchingWithOptions:)`. For a tutorial on the best practices for implementing the delegate, we recommend checking out our <doc:GettingStarted> article.
  /// - Parameters:
  ///   - apiKey: Your Public API Key that you can get from the Superwall dashboard settings. If you don't have an account, you can [sign up for free](https://superwall.com/sign-up).
  ///   - delegate: A class that conforms to ``SuperwallDelegate``. The delegate methods receive callbacks from the SDK in response to certain events on the paywall.
  ///   - options: A ``SuperwallOptions`` object which allows you to customise the appearance and behavior of the paywall.
  /// - Returns: The newly configured ``SuperwallKit/Superwall`` instance.
  @discardableResult
  public static func configure(
    apiKey: String,
    delegate: SuperwallDelegate? = nil,
    purchasingDelegate: SuperwallPurchasingDelegate? = nil,
    options: SuperwallOptions? = nil
  ) -> Superwall {
    guard superwall == nil else {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Superwall.configure called multiple times. Please make sure you only call this once on app launch."
      )
      return shared
    }
    superwall = Superwall(
      apiKey: apiKey,
      delegate: delegate,
      swiftPurchasingDelegate: purchasingDelegate,
      objcPurchasingDelegate: nil,
      options: options
    )
    return shared
  }

  /// Objective-C only function that configures a shared instance of ``SuperwallKit/Superwall`` for use throughout your app.
  ///
  /// Call this as soon as your app finishes launching in `application(_:didFinishLaunchingWithOptions:)`. For a tutorial on the best practices for implementing the delegate, we recommend checking out our <doc:GettingStarted> article.
  /// - Parameters:
  ///   - apiKey: Your Public API Key that you can get from the Superwall dashboard settings. If you don't have an account, you can [sign up for free](https://superwall.com/sign-up).
  ///   - delegate: A class that conforms to ``SuperwallDelegate``. The delegate methods receive callbacks from the SDK in response to certain events on the paywall.
  ///   - options: A ``SuperwallOptions`` object which allows you to customise the appearance and behavior of the paywall.
  /// - Returns: The newly configured ``SuperwallKit/Superwall`` instance.
  @discardableResult
  @available(swift, obsoleted: 1.0)
  public static func configure(
    apiKey: String,
    delegate: SuperwallDelegate? = nil,
    purchasingDelegate: SuperwallPurchasingDelegateObjc? = nil,
    options: SuperwallOptions? = nil
  ) -> Superwall {
    guard superwall == nil else {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Superwall.configure called multiple times. Please make sure you only call this once on app launch."
      )
      return shared
    }
    superwall = Superwall(
      apiKey: apiKey,
      delegate: delegate,
      swiftPurchasingDelegate: nil,
      objcPurchasingDelegate: purchasingDelegate,
      options: options
    )

    return shared
  }

  // MARK: - Preloading

  /// Preloads all paywalls that the user may see based on campaigns and triggers turned on in your Superwall dashboard.
  ///
  /// To use this, first set ``PaywallOptions/shouldPreload``  to `false` when configuring the SDK. Then call this function when you would like preloading to begin.
  ///
  /// Note: This will not reload any paywalls you've already preloaded via ``SuperwallKit/Superwall/preloadPaywalls(forEvents:)``.
  public static func preloadAllPaywalls() {
    Task.detached(priority: .userInitiated) {
      await shared.dependencyContainer.configManager.preloadAllPaywalls()
    }
  }

  /// Preloads paywalls for specific event names.
  ///
  /// To use this, first set ``PaywallOptions/shouldPreload``  to `false` when configuring the SDK. Then call this function when you would like preloading to begin.
  ///
  /// Note: This will not reload any paywalls you've already preloaded.
  public static func preloadPaywalls(forEvents eventNames: Set<String>) {
    Task.detached(priority: .userInitiated) {
      await shared.dependencyContainer.configManager.preloadPaywalls(for: eventNames)
    }
  }

  // MARK: - Deep Links
  /// Handles a deep link sent to your app to open a preview of your paywall.
  ///
  /// You can preview your paywall on-device before going live by utilizing paywall previews. This uses a deep link to render a preview of a paywall you've configured on the Superwall dashboard on your device. See <doc:InAppPreviews> for more.
  public static func handleDeepLink(_ url: URL) {
    Task.detached(priority: .utility) {
      await track(InternalSuperwallEvent.DeepLink(url: url))
    }
    Task {
      await shared.dependencyContainer.debugManager.handle(deepLinkUrl: url)
    }
  }

  // MARK: - Overrides

	/// Overrides the default device locale for testing purposes.
  ///
  /// You can also preview your paywall in different locales using the in-app debugger. See <doc:InAppPreviews> for more.
	///  - Parameter localeIdentifier: The locale identifier for the language you would like to test.
	public static func localizationOverride(localeIdentifier: String? = nil) {
    shared.dependencyContainer.localizationManager.selectedLocale = localeIdentifier
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
      dismiss(
        paywallViewController,
        state: .closed
      )
    case .initiatePurchase(let productId):
      await dependencyContainer.transactionManager.purchase(
        productId,
        from: paywallViewController
      )
    case .initiateRestore:
      await dependencyContainer.restorationHandler.tryToRestore(paywallViewController)
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
