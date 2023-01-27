//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/12/2022.
//

import UIKit

/// Contains all of the SDK's core utility objects that are normally directly injected as dependencies.
///
/// This conforms to protocol factory methods which can be used to make objects that have
/// dependencies injected into them.
///
/// Objects only need `unowned` references to the dependencies injected into them because
/// `DependencyContainer` is owned by the `Superwall` class.
///
/// Idea taken from: [swiftbysundell.com](https://www.swiftbysundell.com/articles/dependency-injection-using-factories-in-swift/)
final class DependencyContainer {
  lazy var storeKitManager = StoreKitManager(factory: self)
  let delegateAdapter: SuperwallDelegateAdapter
  lazy var localizationManager = LocalizationManager()
  lazy var storage = Storage(factory: self)
  lazy var network = Network(factory: self)
  lazy var paywallRequestManager = PaywallRequestManager(
    storeKitManager: storeKitManager,
    factory: self
  )
  lazy var paywallManager = PaywallManager(
    factory: self,
    paywallRequestManager: paywallRequestManager
  )
  lazy var configManager = ConfigManager(
    options: options,
    storeKitManager: storeKitManager,
    storage: storage,
    network: network,
    paywallManager: paywallManager,
    factory: self
  )
  lazy var api = Api(networkEnvironment: configManager.options.networkEnvironment)
  lazy var deviceHelper = DeviceHelper(
    api: api,
    storage: storage,
    localizationManager: localizationManager,
    factory: self
  )
  lazy var queue = EventsQueue(
    network: network,
    configManager: configManager
  )
  lazy var appSessionManager = AppSessionManager(
    configManager: configManager,
    storage: storage,
    delegate: self
  )
  lazy var identityManager = IdentityManager(
    deviceHelper: deviceHelper,
    storage: storage,
    configManager: configManager
  )
  lazy var sessionEventsManager = SessionEventsManager(
    queue: SessionEventsQueue(
      storage: storage,
      network: network,
      configManager: configManager
    ),
    storage: storage,
    network: network,
    configManager: configManager,
    factory: self
  )
  lazy var debugManager = DebugManager(
    storage: storage,
    factory: self
  )
  lazy var transactionManager = TransactionManager(
    storeKitManager: storeKitManager,
    sessionEventsManager: sessionEventsManager
  )
  lazy var restorationManager = RestorationManager(
    storeKitManager: storeKitManager,
    sessionEventsManager: sessionEventsManager
  )
  private let options: SuperwallOptions?

  init(
    swiftDelegate: SuperwallDelegate? = nil,
    objcDelegate: SuperwallDelegateObjc? = nil,
    options: SuperwallOptions? = nil
  ) {
    delegateAdapter = SuperwallDelegateAdapter(
      swiftDelegate: swiftDelegate,
      objcDelegate: objcDelegate
    )
    self.options = options

    // Make sure this lazy var is initialised immediately
    // due to needing session tracking.
    _ = appSessionManager
  }
}

// MARK: - IdentityInfoFactory
extension DependencyContainer: IdentityInfoFactory {
  func makeIdentityInfo() -> IdentityInfo {
    return IdentityInfo(
      aliasId: identityManager.aliasId,
      appUserId: identityManager.appUserId
    )
  }
}

// MARK: - AppManagerDelegate
extension DependencyContainer: AppManagerDelegate {
  func didUpdateAppSession(_ appSession: AppSession) async {
    await sessionEventsManager.updateAppSession(appSession)
  }
}

// MARK: - CacheFactory
extension DependencyContainer: CacheFactory {
  func makeCache() -> PaywallCache {
    return PaywallCache(deviceLocaleString: deviceHelper.locale)
  }
}

// MARK: - DeviceInfofactory
extension DependencyContainer: DeviceInfoFactory {
  func makeDeviceInfo() -> DeviceInfo {
    return DeviceInfo(
      appInstalledAtString: deviceHelper.appInstalledAtString,
      locale: deviceHelper.locale
    )
  }
}

// MARK: - ViewControllerFactory
extension DependencyContainer: ViewControllerFactory {
  @MainActor
  func makePaywallViewController(for paywall: Paywall) -> PaywallViewController {
    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: sessionEventsManager,
      factory: self
    )
    let webView = SWWebView(
      isMac: deviceHelper.isMac,
      sessionEventsManager: sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallViewController = PaywallViewController(
      paywall: paywall,
      delegate: Superwall.shared,
      deviceHelper: deviceHelper,
      sessionEventsManager: sessionEventsManager,
      storage: storage,
      paywallManager: paywallManager,
      webView: webView
    )

    webView.delegate = paywallViewController
    messageHandler.delegate = paywallViewController

    return paywallViewController
  }

  @MainActor
  func makeDebugViewController(withDatabaseId id: String?) -> DebugViewController {
    let viewController = DebugViewController(
      storeKitManager: storeKitManager,
      network: network,
      paywallRequestManager: paywallRequestManager,
      paywallManager: paywallManager,
      localizationManager: localizationManager,
      debugManager: debugManager,
      factory: self
    )
    viewController.paywallDatabaseId = id
    viewController.modalPresentationStyle = .overFullScreen
    return viewController
  }
}

extension DependencyContainer: VariablesFactory {
  func makeJsonVariables(productVariables: [ProductVariable]?, params: JSON?) -> JSON {
    return Variables(
      productVariables: productVariables,
      params: params,
      userAttributes: identityManager.userAttributes,
      templateDeviceDictionary: deviceHelper.templateDevice.dictionary()
    ).templated()
  }
}

// MARK: - PaywallRequestFactory
extension DependencyContainer: RequestFactory {
  func makePaywallRequest(
    eventData: EventData? = nil,
    responseIdentifiers: ResponseIdentifiers,
    overrides: PaywallRequest.Overrides? = nil
  ) -> PaywallRequest {
    return PaywallRequest(
      eventData: eventData,
      responseIdentifiers: responseIdentifiers,
      dependencyContainer: self
    )
  }

  func makePresentationRequest(
    _ presentationInfo: PresentationInfo,
    paywallOverrides: PaywallOverrides? = nil,
    presentingViewController: UIViewController? = nil,
    isDebuggerLaunched: Bool? = nil,
    isUserSubscribed: Bool? = nil,
    isPaywallPresented: Bool
  ) -> PresentationRequest {
    return PresentationRequest(
      presentationInfo: presentationInfo,
      presentingViewController: presentingViewController,
      paywallOverrides: paywallOverrides,
      flags: .init(
        isDebuggerLaunched: isDebuggerLaunched ?? debugManager.isDebuggerLaunched,
        isUserSubscribed: isUserSubscribed ?? storeKitManager.coordinator.subscriptionStatusHandler.isSubscribed(),
        isPaywallPresented: isPaywallPresented
      ),
      dependencyContainer: self
    )
  }
}

// MARK: - ApiFactory
extension DependencyContainer: ApiFactory {
  func makeHeaders(
    fromRequest request: URLRequest,
    requestId: String
  ) -> [String: String] {
    let auth = "Bearer \(storage.apiKey)"
    let headers = [
      "Authorization": auth,
      "X-Platform": "iOS",
      "X-Platform-Environment": "SDK",
      "X-App-User-ID": identityManager.appUserId ?? "",
      "X-Alias-ID": identityManager.aliasId,
      "X-URL-Scheme": deviceHelper.urlScheme,
      "X-Vendor-ID": deviceHelper.vendorId,
      "X-App-Version": deviceHelper.appVersion,
      "X-OS-Version": deviceHelper.osVersion,
      "X-Device-Model": deviceHelper.model,
      "X-Device-Locale": deviceHelper.locale,
      "X-Device-Language-Code": deviceHelper.languageCode,
      "X-Device-Currency-Code": deviceHelper.currencyCode,
      "X-Device-Currency-Symbol": deviceHelper.currencySymbol,
      "X-Device-Timezone-Offset": deviceHelper.secondsFromGMT,
      "X-App-Install-Date": deviceHelper.appInstalledAtString,
      "X-Radio-Type": deviceHelper.radioType,
      "X-Device-Interface-Style": deviceHelper.interfaceStyle,
      "X-SDK-Version": sdkVersion,
      "X-Request-Id": requestId,
      "X-Bundle-ID": deviceHelper.bundleId,
      "X-Low-Power-Mode": deviceHelper.isLowPowerModeEnabled,
      "X-Is-Sandbox": deviceHelper.isSandbox,
      "Content-Type": "application/json"
    ]

    return headers
  }
}

// MARK: - Rule Params
extension DependencyContainer: RuleAttributesFactory {
  func makeRuleAttributes() -> RuleAttributes {
    var userAttributes = identityManager.userAttributes
    userAttributes["isLoggedIn"] = identityManager.isLoggedIn

    return RuleAttributes(
      user: userAttributes,
      device: deviceHelper.templateDevice.toDictionary()
    )
  }
}

// MARK: - TriggerSessionManager
extension DependencyContainer: TriggerSessionManagerFactory {
  func makeTriggerSessionManager() -> TriggerSessionManager {
    // Separating delegate and sessionEventsManager to support testing.
    return TriggerSessionManager(
      delegate: sessionEventsManager,
      sessionEventsManager: sessionEventsManager,
      storage: storage,
      configManager: configManager,
      appSessionManager: appSessionManager,
      identityManager: identityManager
    )
  }
}

// MARK: - StoreKitCoordinatorFactory
extension DependencyContainer: StoreKitCoordinatorFactory {
  func makeStoreKitCoordinator() -> StoreKitCoordinator {
    return StoreKitCoordinator(
      delegateAdapter: delegateAdapter,
      storeKitManager: storeKitManager,
      factory: self
    )
  }
}

// MARK: - StoreTransactionFactory
extension DependencyContainer: StoreTransactionFactory {
  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction {
    let triggerSession = await sessionEventsManager.triggerSession.activeTriggerSession
    return StoreTransaction(
      transaction: SK1StoreTransaction(transaction: transaction),
      configRequestId: configManager.config?.requestId ?? "",
      appSessionId: appSessionManager.appSession.id,
      triggerSessionId: triggerSession?.id
    )
  }

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction {
    let triggerSession = await sessionEventsManager.triggerSession.activeTriggerSession
    return StoreTransaction(
      transaction: SK2StoreTransaction(transaction: transaction),
      configRequestId: configManager.config?.requestId ?? "",
      appSessionId: appSessionManager.appSession.id,
      triggerSessionId: triggerSession?.id
    )
  }
}

// MARK: - Product Purchaser Factory
extension DependencyContainer: ProductPurchaserFactory {
  func makeSK1ProductPurchaser() -> ProductPurchaserSK1 {
    return ProductPurchaserSK1(
      storeKitManager: storeKitManager,
      sessionEventsManager: sessionEventsManager,
      delegateAdapter: delegateAdapter,
      factory: self
    )
  }
}
