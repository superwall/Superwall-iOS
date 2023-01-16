//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/12/2022.
//
// swiftlint:disable function_body_length

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
  var restorationHandler: RestorationHandler!
  var delegateAdapter: SuperwallDelegateAdapter!
  // swiftlint:enable implicitly_unwrapped_optional

  init(
    apiKey: String,
    swiftDelegate: SuperwallDelegate? = nil,
    objcDelegate: SuperwallDelegateObjc? = nil,
    options: SuperwallOptions? = nil
  ) {
    storeKitManager = StoreKitManager(factory: self)
    delegateAdapter = SuperwallDelegateAdapter(
      swiftDelegate: swiftDelegate,
      objcDelegate: objcDelegate
    )
    localizationManager = LocalizationManager()
    storage = Storage()
    network = Network(factory: self)

    paywallRequestManager = PaywallRequestManager(
      storeKitManager: storeKitManager
    )
    paywallManager = PaywallManager(
      factory: self,
      paywallRequestManager: paywallRequestManager
    )

    configManager = ConfigManager(
      storeKitManager: storeKitManager,
      storage: storage,
      network: network,
      paywallManager: paywallManager,
      factory: self
    )

    if let options = options {
      configManager.options = options
    }

    api = Api(configManager: configManager)

    deviceHelper = DeviceHelper(
      api: api,
      storage: storage,
      localizationManager: localizationManager
    )

    queue = EventsQueue(
      network: network,
      configManager: configManager
    )

    appSessionManager = AppSessionManager(
      configManager: configManager,
      storage: storage
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
      sessionEventsManager: sessionEventsManager
    )

    restorationHandler = RestorationHandler(
      storeKitManager: storeKitManager,
      sessionEventsManager: sessionEventsManager
    )

    // MARK: Post Init

    // We have to call postInit on some of the objects to avoid
    // retain cycles.
    storeKitManager.postInit()
    sessionEventsManager.postInit()
    storage.postInit(deviceHelper: deviceHelper)
    deviceHelper.postInit(identityManager: identityManager)
    configManager.postInit(deviceHelper: deviceHelper)
    paywallManager.postInit(deviceHelper: deviceHelper)
    appSessionManager.postInit(sessionEventsManager: sessionEventsManager)

    Task {
      await paywallRequestManager.postInit(deviceHelper: deviceHelper)
    }
  }
}

// MARK: - ViewControllerFactory
extension DependencyContainer: ViewControllerFactory {
  func makePaywallViewController(for paywall: Paywall) -> PaywallViewController {
    return PaywallViewController(
      paywall: paywall,
      delegate: Superwall.shared,
      deviceHelper: deviceHelper,
      sessionEventsManager: sessionEventsManager,
      storage: storage,
      paywallManager: paywallManager,
      identityManager: identityManager
    )
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

// MARK: - PaywallRequestFactory
extension DependencyContainer: RequestFactory {
  func makePaywallRequest(withId paywallId: String) -> PaywallRequest {
    return PaywallRequest(
      responseIdentifiers: .init(paywallId: paywallId),
      injections: .init(
        sessionEventsManager: sessionEventsManager,
        storeKitManager: storeKitManager,
        configManager: configManager,
        network: network,
        debugManager: debugManager
      )
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
      injections: .init(
        configManager: configManager,
        storage: storage,
        sessionEventsManager: sessionEventsManager,
        paywallManager: paywallManager,
        storeKitManager: storeKitManager,
        network: network,
        debugManager: debugManager,
        identityManager: identityManager,
        deviceHelper: deviceHelper,
        isDebuggerLaunched: isDebuggerLaunched ?? debugManager.isDebuggerLaunched,
        isUserSubscribed: isUserSubscribed ?? storeKitManager.coordinator.subscriptionStatusHandler.isSubscribed(),
        isPaywallPresented: isPaywallPresented
      )
    )
  }
}

// MARK: - ApiFactory
extension DependencyContainer: ApiFactory {
  func makeHeaders(
    fromRequest request: URLRequest,
    requestId: String,
    forDebugging isForDebugging: Bool
  ) -> [String: String] {
    let auth = "Bearer \(storage.apiKey)"
    let headers = [
      "Authorization": auth,
      "X-Platform": "iOS",
      "X-Platform-Environment": "SDK",
      "X-App-User-ID": identityManager.appUserId ?? "",
      "X-Alias-ID": identityManager.aliasId,
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
