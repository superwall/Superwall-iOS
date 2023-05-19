//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/12/2022.
//
// swiftlint:disable function_body_length file_length

import UIKit
import Combine

/// Contains all of the SDK's core utility objects that are normally directly injected as dependencies.
///
/// This conforms to protocol factory methods which can be used to make objects that have
/// dependencies injected into them.
///
/// Objects only need `unowned` references to the dependencies injected into them because
/// `DependencyContainer` is owned by the `Superwall` class.
final class DependencyContainer {
  // swiftlint:disable implicitly_unwrapped_optional
  var configManager: ConfigManager!
  var identityManager: IdentityManager!
  var storeKitManager: StoreKitManager!
  var appSessionManager: AppSessionManager!
  var sessionEventsManager: SessionEventsManager!
  var storage: Storage!
  var network: Network!
  var paywallManager: PaywallManager!
  var paywallRequestManager: PaywallRequestManager!
  var deviceHelper: DeviceHelper!
  var localizationManager: LocalizationManager!
  var queue: EventsQueue!
  var debugManager: DebugManager!
  var api: Api!
  var transactionManager: TransactionManager!
  var delegateAdapter: SuperwallDelegateAdapter!
  // swiftlint:enable implicitly_unwrapped_optional

  init(
    swiftPurchaseController: PurchaseController? = nil,
    objcPurchaseController: PurchaseControllerObjc? = nil,
    options: SuperwallOptions? = nil
  ) {
    storeKitManager = StoreKitManager(factory: self)
    delegateAdapter = SuperwallDelegateAdapter(
      swiftPurchaseController: swiftPurchaseController,
      objcPurchaseController: objcPurchaseController
    )
    localizationManager = LocalizationManager()
    storage = Storage(factory: self)
    network = Network(factory: self)

    paywallRequestManager = PaywallRequestManager(
      storeKitManager: storeKitManager,
      network: network,
      factory: self
    )
    paywallManager = PaywallManager(
      factory: self,
      paywallRequestManager: paywallRequestManager
    )

    configManager = ConfigManager(
      options: options,
      storeKitManager: storeKitManager,
      storage: storage,
      network: network,
      paywallManager: paywallManager,
      factory: self
    )

    api = Api(networkEnvironment: configManager.options.networkEnvironment)

    deviceHelper = DeviceHelper(
      api: api,
      storage: storage,
      factory: self
    )

    queue = EventsQueue(
      network: network,
      configManager: configManager
    )

    appSessionManager = AppSessionManager(
      configManager: configManager,
      storage: storage,
      delegate: self
    )

    identityManager = IdentityManager(
      deviceHelper: deviceHelper,
      storage: storage,
      configManager: configManager
    )

    sessionEventsManager = SessionEventsManager(
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

    debugManager = DebugManager(
      storage: storage,
      factory: self
    )

    transactionManager = TransactionManager(
      storeKitManager: storeKitManager,
      sessionEventsManager: sessionEventsManager,
      factory: self
    )
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
  func makeCache() -> PaywallViewControllerCache {
    return PaywallViewControllerCache(deviceLocaleString: deviceHelper.locale)
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

// MARK: - DeviceInfofactory
extension DependencyContainer: LocaleIdentifierFactory {
  func makeLocaleIdentifier() -> String? {
    return configManager.options.localeIdentifier
  }
}

// MARK: - ViewControllerFactory
extension DependencyContainer: ViewControllerFactory {
  @MainActor
  func makePaywallViewController(
    for paywall: Paywall,
    withCache cache: PaywallViewControllerCache?,
    delegate: PaywallViewControllerDelegateAdapter?
  ) -> PaywallViewController {
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
      eventDelegate: Superwall.shared,
      delegate: delegate,
      deviceHelper: deviceHelper,
      factory: self,
      storage: storage,
      paywallManager: paywallManager,
      webView: webView,
      cache: cache
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
  func makeJsonVariables(productVariables: [ProductVariable]?, params: JSON?) async -> JSON {
    let templateDeviceDict = await deviceHelper.getTemplateDevice().dictionary()

    return Variables(
      productVariables: productVariables,
      params: params,
      userAttributes: identityManager.userAttributes,
      templateDeviceDictionary: templateDeviceDict
    ).templated()
  }
}

// MARK: - PaywallRequestFactory
extension DependencyContainer: RequestFactory {
  func makePaywallRequest(
    eventData: EventData? = nil,
    responseIdentifiers: ResponseIdentifiers,
    overrides: PaywallRequest.Overrides? = nil,
    isDebuggerLaunched: Bool
  ) -> PaywallRequest {
    return PaywallRequest(
      eventData: eventData,
      responseIdentifiers: responseIdentifiers,
      overrides: overrides ?? PaywallRequest.Overrides(),
      isDebuggerLaunched: isDebuggerLaunched
    )
  }

  func makePresentationRequest(
    _ presentationInfo: PresentationInfo,
    paywallOverrides: PaywallOverrides? = nil,
    presenter: UIViewController? = nil,
    isDebuggerLaunched: Bool? = nil,
    subscriptionStatus: AnyPublisher<SubscriptionStatus, Never>? = nil,
    isPaywallPresented: Bool,
    type: PresentationRequestType
  ) -> PresentationRequest {
    let hasInternet = deviceHelper.reachabilityFlags?.contains(.reachable) ?? false

    return PresentationRequest(
      presentationInfo: presentationInfo,
      presenter: presenter,
      paywallOverrides: paywallOverrides,
      flags: .init(
        isDebuggerLaunched: isDebuggerLaunched ?? debugManager.isDebuggerLaunched,
        subscriptionStatus: subscriptionStatus ?? Superwall.shared.$subscriptionStatus.eraseToAnyPublisher(),
        isPaywallPresented: isPaywallPresented,
        type: type,
        hasInternet: hasInternet
      )
    )
  }
}

// MARK: - ApiFactory
extension DependencyContainer: ApiFactory {
  func makeHeaders(
    fromRequest request: URLRequest,
    isForDebugging: Bool,
    requestId: String
  ) async -> [String: String] {
    let key = isForDebugging ? storage.debugKey : storage.apiKey
    let auth = "Bearer \(key)"
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
  func makeRuleAttributes() async -> RuleAttributes {
    var userAttributes = identityManager.userAttributes
    userAttributes["isLoggedIn"] = identityManager.isLoggedIn
    let device = await deviceHelper.getTemplateDevice().toDictionary()

    return RuleAttributes(
      user: userAttributes,
      device: device
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

  func getTriggerSessionManager() -> TriggerSessionManager {
    return sessionEventsManager.triggerSession
  }
}

// MARK: - ConfigManagerFactory
extension DependencyContainer: ConfigManagerFactory {
  /// Gets the paywall response from the static config, if the device locale starts with "en" and no more specific version can be found.
  func makeStaticPaywall(withId paywallId: String?) -> Paywall? {
    let deviceInfo = makeDeviceInfo()
    return ConfigLogic.getStaticPaywall(
      withId: paywallId,
      config: configManager.config,
      deviceLocale: deviceInfo.locale
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

// MARK: - Purchase Manager Factory
extension DependencyContainer: PurchaseManagerFactory {
  func makePurchaseManager() -> PurchaseManager {
    return PurchaseManager(
      storeKitManager: storeKitManager,
      hasPurchaseController: delegateAdapter.hasPurchaseController
    )
  }
}
