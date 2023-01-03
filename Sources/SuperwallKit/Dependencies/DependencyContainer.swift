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
  /// The purchasing delegate adapter. Routes swift vs. objective-c callbacks.
  var purchasingDelegateAdapter: SuperwallPurchasingDelegateAdapter!
  var configManager: ConfigManager!
  var identityManager: IdentityManager!
  var storeKitManager: StoreKitManager!
  // TODO: Make sure this is loaded straight away:
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

  init(
    apiKey: String,
    delegate: SuperwallDelegate? = nil,
    swiftPurchasingDelegate: SuperwallPurchasingDelegate? = nil,
    objcPurchasingDelegate: SuperwallPurchasingDelegateObjc? = nil,
    options: SuperwallOptions? = nil
  ) {
    purchasingDelegateAdapter = SuperwallPurchasingDelegateAdapter(
      swiftDelegate: swiftPurchasingDelegate,
      objcDelegate: objcPurchasingDelegate
    )

    localizationManager = LocalizationManager()
    storage = Storage()
    network = Network(factory: self)

    storeKitManager = StoreKitManager(factory: self)
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
    // If there is a purchasing delegate set, we must never finish transactions.
    // That is up to the developer to do with their purchasing logic.
    if purchasingDelegateAdapter.hasDelegate {
      configManager.options.finishTransactions = false
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
    isDebuggerLaunched: Bool,
    isUserSubscribed: Bool,
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
        isDebuggerLaunched: isDebuggerLaunched,
        isUserSubscribed: isUserSubscribed,
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
    return TriggerSessionManager(
      delegate: sessionEventsManager,
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
      purchasingDelegateAdapter: purchasingDelegateAdapter,
      storeKitManager: storeKitManager,
      finishTransactions: configManager.options.finishTransactions,
      sessionEventsManager: sessionEventsManager,
      factory: self
    )
  }
}

// MARK: - StoreTransactionFactory
extension DependencyContainer: StoreTransactionFactory {
  @available(iOS 15.0, *)
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction {
    return await StoreTransaction.create(
      from: transaction,
      sessionEventsManager: sessionEventsManager,
      configManager: configManager,
      appSessionManager: appSessionManager
    )
  }

  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction {
    return await StoreTransaction.create(
      from: transaction,
      sessionEventsManager: sessionEventsManager,
      configManager: configManager,
      appSessionManager: appSessionManager
    )
  }
}
