import Foundation
import StoreKit
import Combine

/// The primary class for integrating Superwall into your application. After configuring via
/// ``configure(apiKey:delegate:options:)-65jyx``, It provides access to
/// all its featured via instance functions and variables.
@objcMembers
public final class Superwall: NSObject, ObservableObject {
  // MARK: - Public Properties
  /// The optional purchasing delegate of the Superwall instance. Set this in
  /// ``configure(apiKey:delegate:options:)-65jyx``
  /// when you want to manually handle the purchasing logic within your app.
  public var delegate: SuperwallDelegate? {
    get {
      return dependencyContainer.delegateAdapter.swiftDelegate
    }
    set {
      dependencyContainer.delegateAdapter.swiftDelegate = newValue
      dependencyContainer.storeKitManager.coordinator.didToggleDelegate()
    }
  }

  /// The optional purchasing delegate of the Superwall instance. Set this in
  /// ``configure(apiKey:delegate:options:)-65jyx``
  /// when you want to manually handle the purchasing logic within your app.
  @available(swift, obsoleted: 1.0)
  @objc(delegate)
  public var objcDelegate: SuperwallDelegateObjc? {
    get {
      return dependencyContainer.delegateAdapter.objcDelegate
    }
    set {
      dependencyContainer.delegateAdapter.objcDelegate = newValue
      dependencyContainer.storeKitManager.coordinator.didToggleDelegate()
    }
  }

  /// Specifies the detail of the logs returned from the SDK to the console.
  public var logLevel: LogLevel? {
    get {
      return options.logging.level
    }
    set {
      options.logging.level = newValue
    }
  }

  /// Properties stored about the user, set using ``setUserAttributes(_:)``.
  public var userAttributes: [String: Any] {
    return dependencyContainer.identityManager.userAttributes
  }

  /// The presented paywall view controller.
  @MainActor
  public var presentedViewController: UIViewController? {
    return dependencyContainer.paywallManager.presentedViewController
  }

  /// A convenience variable to access and change the paywall options that you passed
  /// to ``configure(apiKey:delegate:options:)-65jyx``.
  public var options: SuperwallOptions {
    return dependencyContainer.configManager.options
  }

  /// The ``PaywallInfo`` object of the most recently presented view controller.
  @MainActor
  public var latestPaywallInfo: PaywallInfo? {
    let presentedPaywallInfo = dependencyContainer.paywallManager.presentedViewController?.paywallInfo
    return presentedPaywallInfo ?? presentationItems.paywallInfo
  }

  /// The current user's id.
  ///
  /// If you haven't called ``logIn(userId:)`` or ``createAccount(userId:)``,
  /// this value will return an anonymous user id which is cached to disk
  public var userId: String {
    return dependencyContainer.identityManager.userId
  }

  /// Indicates whether the user is logged in to Superwall.
  ///
  /// If you have previously called ``logIn(userId:)`` or
  /// ``createAccount(userId:)``, this will return true.
  ///
  /// - Returns: A boolean indicating whether the user is logged in or not.
  public var isLoggedIn: Bool {
    return dependencyContainer.identityManager.isLoggedIn
  }

  /// A published property that indicates whether the device has any active subscriptions.
  ///
  /// Its value is stored on disk and synced with the active purchases on device.
  ///
  /// If you're using Combine or SwiftUI, you can subscribe or bind to this to get
  /// notified whenever the user's subscription status changes.
  ///
  /// If you are returning a ``SubscriptionController`` in the
  /// ``SuperwallDelegate``, you should rely on your own subscription status instead.
  @Published
  public var hasActiveSubscription = false {
    didSet {
      dependencyContainer.storage.save(hasActiveSubscription, forType: SubscriptionStatus.self)
    }
  }

  /// A published property that is `true` when Superwall has finished configuring via
  /// ``configure(apiKey:delegate:options:)-65jyx``.
  ///
  /// If you're using Combine or SwiftUI, you can subscribe or bind to this to get
  /// notified when configuration has completed.
  @Published
  public var isConfigured = false

  /// The configured shared instance of ``Superwall``.
  ///
  /// - Warning: You must call ``configure(apiKey:delegate:options:)-65jyx``
  /// to initialize ``Superwall`` before using this.
  @objc(sharedInstance)
  public static var shared: Superwall {
    guard let superwall = superwall else {
      #if DEBUG
      // Code only executes when tests are running in a debug environment.
      // This avoids lots of irrelevent error messages printed to console about Superwall not
      // being configured, which slows down the tests.
      if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        let superwall = Superwall()
        self.superwall = superwall
        return superwall
      }
      #endif
      Logger.debug(
        logLevel: .error,
        scope: .superwallCore,
        message: "Superwall has not been configured. Please call Superwall.configure()"
      )
      return Superwall()
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
  let dependencyContainer: DependencyContainer

  // MARK: - Private Functions
  init(dependencyContainer: DependencyContainer = DependencyContainer()) {
    self.dependencyContainer = dependencyContainer
    super.init()
  }

  private convenience init(
    apiKey: String,
    swiftDelegate: SuperwallDelegate? = nil,
    objcDelegate: SuperwallDelegateObjc? = nil,
    options: SuperwallOptions? = nil
  ) {
    let dependencyContainer = DependencyContainer(
      swiftDelegate: swiftDelegate,
      objcDelegate: objcDelegate,
      options: options
    )
    self.init(dependencyContainer: dependencyContainer)

    hasActiveSubscription = dependencyContainer.storage.get(SubscriptionStatus.self) ?? false

    listenForConfig()

    // This task runs on a background thread, even if called from a main thread.
    // This is because the function isn't marked to run on the main thread,
    // therefore, we don't need to make this detached.
    Task {
      dependencyContainer.storage.configure(apiKey: apiKey)

      dependencyContainer.storage.recordAppInstall()

      await dependencyContainer.configManager.fetchConfiguration()
      await dependencyContainer.identityManager.configure()
    }
  }

  /// Listens to config and updates ``isConfigured`` when it receives a non-nil value
  /// for config.
  private func listenForConfig() {
    dependencyContainer.configManager.$config
      .compactMap { $0 }
      .first()
      .receive(on: DispatchQueue.main)
      .subscribe(Subscribers.Sink(
        receiveCompletion: { _ in },
        receiveValue: { config in
          self.isConfigured = config != nil
        }
      ))
  }

  // MARK: - Configuration
  /// Configures a shared instance of ``Superwall`` for use throughout your app.
  ///
  /// Call this as soon as your app finishes launching in `application(_:didFinishLaunchingWithOptions:)`.
  /// Check out our <doc:GettingStarted> article for a tutorial on how to configure the SDK.
  /// - Parameters:
  ///   - apiKey: Your Public API Key that you can get from the Superwall dashboard settings. If you don't have
  ///   an account, you can [sign up for free](https://superwall.com/sign-up).
  ///   - delegate: An optional class that conforms to ``SuperwallDelegate``. The delegate methods receive
  ///   callbacks from the SDK in response to certain events on the paywall.
  ///   - options: A ``SuperwallOptions`` object which allows you to customise the appearance and behavior
  ///   of the paywall.
  /// - Returns: The newly configured ``Superwall`` instance.
  @discardableResult
  public static func configure(
    apiKey: String,
    delegate: SuperwallDelegate? = nil,
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
      swiftDelegate: delegate,
      objcDelegate: nil,
      options: options
    )
    return shared
  }

  /// Objective-C only function that configures a shared instance of ``SuperwallKit/Superwall`` for use throughout your app.
  ///
  /// Call this as soon as your app finishes launching in `application(_:didFinishLaunchingWithOptions:)`. Check out our <doc:GettingStarted> article for a tutorial on how to configure the SDK.
  /// - Parameters:
  ///   - apiKey: Your Public API Key that you can get from the Superwall dashboard settings. If you don't have an account, you can [sign up for free](https://superwall.com/sign-up).
  ///   - delegate: An optional class that conforms to ``SuperwallDelegate``. The delegate methods receive callbacks from the SDK in response to certain events on the paywall.
  ///   - options: A ``SuperwallOptions`` object which allows you to customise the appearance and behavior of the paywall.
  /// - Returns: The newly configured ``SuperwallKit/Superwall`` instance.
  @discardableResult
  @available(swift, obsoleted: 1.0)
  public static func configure(
    apiKey: String,
    delegate: SuperwallDelegateObjc? = nil,
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
      swiftDelegate: nil,
      objcDelegate: delegate,
      options: options
    )
    return shared
  }

  // MARK: - Preloading

  /// Preloads all paywalls that the user may see based on campaigns and triggers turned on in your Superwall dashboard.
  ///
  /// To use this, first set ``PaywallOptions/shouldPreload``  to `false` when configuring the SDK. Then call this function when you would like preloading to begin.
  ///
  /// Note: This will not reload any paywalls you've already preloaded via ``preloadPaywalls(forEvents:)``.
  public func preloadAllPaywalls() {
    Task { [weak self] in
      await self?.dependencyContainer.configManager.preloadAllPaywalls()
    }
  }

  /// Preloads paywalls for specific event names.
  ///
  /// To use this, first set ``PaywallOptions/shouldPreload``  to `false` when configuring the SDK. Then call this function when you would like preloading to begin.
  ///
  /// Note: This will not reload any paywalls you've already preloaded.
  public func preloadPaywalls(forEvents eventNames: Set<String>) {
    Task { [weak self] in
      await self?.dependencyContainer.configManager.preloadPaywalls(for: eventNames)
    }
  }

  // MARK: - Deep Links
  /// Handles a deep link sent to your app to open a preview of your paywall.
  ///
  /// You can preview your paywall on-device before going live by utilizing paywall previews. This uses a deep link to render a preview of a paywall you've configured on the Superwall dashboard on your device. See <doc:InAppPreviews> for more.
  public func handleDeepLink(_ url: URL) {
    Task {
      await track(InternalSuperwallEvent.DeepLink(url: url))
      await dependencyContainer.debugManager.handle(deepLinkUrl: url)
    }
  }

  // MARK: - Overrides

	/// Overrides the default device locale for testing purposes.
  ///
  /// You can also preview your paywall in different locales using the in-app debugger. See <doc:InAppPreviews> for more.
	///  - Parameter localeIdentifier: The locale identifier for the language you would like to test.
	public func localizationOverride(localeIdentifier: String? = nil) {
    dependencyContainer.localizationManager.selectedLocale = localeIdentifier
	}
}

// MARK: - PaywallViewControllerDelegate
extension Superwall: PaywallViewControllerDelegate {
  @MainActor
  func eventDidOccur(
    _ paywallEvent: PaywallWebEvent,
    on paywallViewController: PaywallViewController
  ) async {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Event Did Occur",
      info: ["event": paywallEvent]
    )

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
      await dependencyContainer.restorationManager.tryToRestore(paywallViewController)
    case .openedURL(let url):
      dependencyContainer.delegateAdapter.willOpenURL(url: url)
    case .openedUrlInSafari(let url):
      dependencyContainer.delegateAdapter.willOpenURL(url: url)
    case .openedDeepLink(let url):
      dependencyContainer.delegateAdapter.willOpenDeepLink(url: url)
    case .custom(let string):
      dependencyContainer.delegateAdapter.handleCustomPaywallAction(withName: string)
    }
  }
}
