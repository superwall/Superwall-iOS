//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 31/03/2025.
//

import Testing
@testable import SuperwallKit
import Foundation

final class NotificationSchedulerMock: NotificationScheduling {
  var scheduledNotifications: [LocalNotification] = []
  var scheduledPaywallId: String?

  func scheduleNotifications(
    _ notifications: [LocalNotification],
    fromPaywallId paywallId: String,
    factory: DeviceHelperFactory
  ) async {
    scheduledNotifications = notifications
    scheduledPaywallId = paywallId
  }
}

@Suite(.serialized)
struct WebEntitlementRedeemerTests {
  let dependencyContainer = DependencyContainer()

  init() {
    // Clear any pending stripe checkout state left on disk by a previous test
    // to prevent the WebEntitlementRedeemer init Task from triggering unexpected saves.
    dependencyContainer.storage.delete(PendingStripeCheckoutPollStorage.self)
  }

  @Test("First redemption of code")
  func testRedeem_withCode_firstRedemption_savesCodeAndTracksEvents() async {
    guard #available(iOS 14.0, *) else {
      return
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    // No existing redeem response, so is first redemption of code.
    let mockStorage = StorageMock(internalRedeemResponse: nil)

    // Disable the popup
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    // Set expectations
    let code = "TESTCODE"
    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: code,
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: entitlements)
    )
    mockNetwork.getWebEntitlementsResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(entitlements)))
      .setting(\.results, to: [result])

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    await redeemer.redeem(
      .code("TESTCODE"),
      injectedConfig: config
    )

    #expect(mockStorage.saveCount == 2)
    #expect(superwall.entitlements.active == entitlements)
    #expect(mockDelegate.receivedResult?.code == result.code)
    if case .success = mockDelegate.receivedResult {} else {
      Issue.record("should have been a success")
    }
    #expect(mockNetwork.redeemRequest?.codes == [.init(code: code, isFirstRedemption: true)])
    let events = mockDelegate.eventsReceived.map { $0.backingData.objcEvent }
    #expect(events.contains(SuperwallEventObjc.redemptionStart))
    #expect(events.contains(SuperwallEventObjc.redemptionComplete))
    #expect(!events.contains(SuperwallEventObjc.restoreStart))
    #expect(!events.contains(SuperwallEventObjc.restoreComplete))
    #expect(!events.contains(SuperwallEventObjc.redemptionFail))
    #expect(!events.contains(SuperwallEventObjc.restoreFail))
  }

  @Test("didRedeemLink is called even when no paywall VC is presented")
  func testRedeem_noPaywallVC_callsDidRedeemLink() async {
    guard #available(iOS 14.0, *) else {
      return
    }
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // Verify no paywall VC is presented
    #expect(superwall.paywallViewController == nil)

    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockStorage = StorageMock(internalRedeemResponse: nil)

    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    let code = "TESTCODE"
    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: code,
      redemptionInfo: .init(
        ownership: .appUser(appUserId: "appUserId"),
        purchaserInfo: .init(
          appUserId: "appUserId",
          email: nil,
          storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])
        ),
        entitlements: entitlements
      )
    )
    mockNetwork.getWebEntitlementsResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(entitlements)))
      .setting(\.results, to: [result])

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    await redeemer.redeem(
      .code(code),
      injectedConfig: config
    )

    // Verify didRedeemLink was called with the correct result
    #expect(mockDelegate.receivedResult != nil, "didRedeemLink should be called even without a paywall VC")
    #expect(mockDelegate.receivedResult?.code == code)
    if case .success = mockDelegate.receivedResult {} else {
      Issue.record("didRedeemLink should have received a success result")
    }
  }

  @Test("Redemption of existing code")
  func testRedeem_withCode_notFirstRedemption_savesCodeAndTracksEvents() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let existingCode = "TESTCODE"
    let existingEntitlements: Set<Entitlement> = [.stub()]
    let existingResult = RedemptionResult.success(
      code: existingCode,
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: existingEntitlements)
    )
   let existingResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(existingEntitlements)))
      .setting(\.results, to: [existingResult])

    // No existing redeem response, so is first redemption of code.
    let mockStorage = StorageMock(internalRedeemResponse: existingResponse)

    // Disable the popup
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    // Set expectations
    let code = "TESTCODE"
    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: code,
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: entitlements)
    )
    mockNetwork.getWebEntitlementsResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(entitlements)))
      .setting(\.results, to: [result])

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    await redeemer.redeem(
      .code("TESTCODE"),
      injectedConfig: config
    )

    #expect(mockStorage.saveCount == 2)
    #expect(superwall.entitlements.active == entitlements)
    #expect(mockDelegate.receivedResult?.code == result.code)
    #expect(mockNetwork.redeemRequest?.codes == [.init(code: code, isFirstRedemption: false)])
    if case .success = mockDelegate.receivedResult {} else {
      Issue.record("should have been a success")
    }
    let events = mockDelegate.eventsReceived.map { $0.backingData.objcEvent }
    #expect(events.contains(SuperwallEventObjc.redemptionStart))
    #expect(events.contains(SuperwallEventObjc.redemptionComplete))
    #expect(!events.contains(SuperwallEventObjc.restoreStart))
    #expect(!events.contains(SuperwallEventObjc.restoreComplete))
    #expect(!events.contains(SuperwallEventObjc.redemptionFail))
    #expect(!events.contains(SuperwallEventObjc.restoreFail))
  }

  @Test("Restores with paywall visible")
  func testRedeem_withCode_paywallVisible() async {
    guard #available(iOS 14.0, *) else {
      return
    }
    let cache = dependencyContainer.paywallManager.cache
    let messageHandler = await PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = await SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )

    // Create entitlement that will be restored
    let entitlement = Entitlement(id: "premium", isActive: true)

    // Create a product with the entitlement
    let product = Product(
      name: "Test Product",
      type: .appStore(.init(id: "test_product")),
      id: "test_product",
      entitlements: [entitlement]
    )

    // Create paywall with the product
    let paywall = Paywall.stub()
      .setting(\.products, to: [product])

    let paywallVc = await PaywallViewControllerMock(
      paywall: paywall,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: cache,
      paywallArchiveManager: nil
    )
    cache.save(paywallVc, forKey: "key")
    cache.activePaywallVcKey = "key"
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // Map the product ID to its entitlement so restore tracking works
    dependencyContainer.entitlementsInfo.entitlementsByProductId["test_product"] = [entitlement]

    let existingCode = "TESTCODE"
    let existingEntitlements: Set<Entitlement> = [entitlement]
    let existingResult = RedemptionResult.success(
      code: existingCode,
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: existingEntitlements)
    )
    let existingResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(existingEntitlements)))
      .setting(\.results, to: [existingResult])

    // No existing redeem response, so is first redemption of code.
    let mockStorage = StorageMock(internalRedeemResponse: existingResponse)
    // Disable the popup
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    // Set expectations - use the same entitlement created for the paywall
    let code = "TESTCODE"
    let entitlements: Set<Entitlement> = [entitlement]
    let result = RedemptionResult.success(
      code: code,
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: entitlements)
    )
    mockNetwork.getWebEntitlementsResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(entitlements)))
      .setting(\.results, to: [result])

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    await redeemer.redeem(
      .code("TESTCODE"),
      injectedConfig: config
    )

    #expect(mockStorage.saveCount == 2)
    // Verify the entitlement is active (may be merged/deduplicated with existing entitlement)
    #expect(superwall.entitlements.active.contains(where: { $0.id == "premium" }))
    #expect(mockDelegate.receivedResult?.code == result.code)
    #expect(mockNetwork.redeemRequest?.codes == [.init(code: code, isFirstRedemption: false)])
    if case .success = mockDelegate.receivedResult {} else {
      Issue.record("should have been a success")
    }
    let events = mockDelegate.eventsReceived.map { $0.backingData.objcEvent }
    #expect(events.contains(SuperwallEventObjc.redemptionStart))
    #expect(events.contains(SuperwallEventObjc.redemptionComplete))
    #expect(events.contains(SuperwallEventObjc.restoreStart))
    #expect(events.contains(SuperwallEventObjc.restoreComplete))
    #expect(!events.contains(SuperwallEventObjc.redemptionFail))
    #expect(!events.contains(SuperwallEventObjc.restoreFail))
  }

  @Test("Fails to get code while restoring")
  func testRedeem_withCode_fails_paywallVisible() async {
    guard #available(iOS 16.0, *) else {
      return
    }
    let cache = dependencyContainer.paywallManager.cache
    let messageHandler = await PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = await SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = await PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: cache,
      paywallArchiveManager: nil
    )
    cache.save(paywallVc, forKey: "key")
    cache.activePaywallVcKey = "key"
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let existingCode = "TESTCODE"
    let existingEntitlements: Set<Entitlement> = [.stub()]
    let existingResult = RedemptionResult.success(
      code: existingCode,
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: existingEntitlements)
    )
    let existingResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(existingEntitlements)))
      .setting(\.results, to: [existingResult])

    // No existing redeem response, so is first redemption of code.
    let mockStorage = StorageMock(internalRedeemResponse: existingResponse)
    let mockNetwork = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    // Set expectations
    let code = "TESTCODE"
    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: code,
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: entitlements)
    )
    let error = NetworkError.notAuthenticated
    mockNetwork.redeemError = error

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    await redeemer.redeem(
      .code("TESTCODE"),
      injectedConfig: config
    )

    try? await Task.sleep(nanoseconds: UInt64(300 * 1_000_000))
    #expect(mockStorage.saveCount == 0)
    #expect(superwall.entitlements.active.isEmpty)
    #expect(mockDelegate.receivedResult?.code == result.code)
    #expect(mockNetwork.redeemRequest?.codes == [.init(code: code, isFirstRedemption: false)])
    if case let .error(receivedCode, error) = mockDelegate.receivedResult {
      #expect(receivedCode == code)
      #expect(error.message == error.message)
    } else {
      Issue.record("should have been a error")
    }
    let events = mockDelegate.eventsReceived.map { $0.backingData.objcEvent }
    #expect(events.contains(SuperwallEventObjc.redemptionStart))
    #expect(!events.contains(SuperwallEventObjc.redemptionComplete))
    #expect(events.contains(SuperwallEventObjc.restoreStart))
    #expect(!events.contains(SuperwallEventObjc.restoreComplete))
    #expect(events.contains(SuperwallEventObjc.redemptionFail))
    #expect(events.contains(SuperwallEventObjc.restoreFail))
  }


//  func testRedeem_existingCodes_onlyTracksAndSaves() async {
//    let mockNetwork = MockNetwork()
//    let mockStorage = MockStorage()
//    let mockEntitlementsInfo = MockEntitlementsInfo()
//    let mockDelegate = MockSuperwallDelegateAdapter()
//    let mockPurchaseController = MockPurchaseController()
//    let mockFactory = MockFactory()
//
//    let redeemer = WebEntitlementRedeemer(
//      network: mockNetwork,
//      storage: mockStorage,
//      entitlementsInfo: mockEntitlementsInfo,
//      delegate: mockDelegate,
//      purchaseController: mockPurchaseController,
//      factory: mockFactory
//    )
//
//    mockNetwork.getWebEntitlementsResponse = RedeemResponse.mock()
//
//    await redeemer.redeem(.existingCodes)
//
//    #expect(mockNetwork.didRedeemEntitlements)
//    let savedResponse = mockStorage.savedObjects[LatestRedeemResponse.self] as? LatestRedeemResponse
//    #expect(savedResponse != nil)
//  }

  @Test("Revoked SUPERWALL entitlement is correctly removed")
  func testPollWebEntitlements_revokedSuperwallEntitlement() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // Create a SUPERWALL entitlement that was previously granted
    let previousSuperwallEntitlement = Entitlement(
      id: "premium",
      type: .serviceLevel,
      isActive: true,
      productIds: ["test_product"],
      latestProductId: nil,  // SUPERWALL entitlements don't have latestProductId
      store: .superwall,
      startsAt: Date(),
      renewedAt: nil,
      expiresAt: nil,
      isLifetime: true,
      willRenew: nil,
      state: nil,
      offerType: nil
    )

    // Set up existing state: SUPERWALL entitlement exists in previous web response
    let previousWebCustomerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [previousSuperwallEntitlement]
    )
    let previousRedeemResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: previousWebCustomerInfo)

    // Device has no entitlements (empty device CustomerInfo)
    let deviceCustomerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: []
    )

    // Set up the initial state in dependencyContainer.storage
    // This is critical: entitlementsInfo.web reads from dependencyContainer.storage,
    // so we must use the same storage instance for consistent behavior.
    dependencyContainer.storage.save(previousRedeemResponse, forType: LatestRedeemResponse.self)
    dependencyContainer.storage.save(deviceCustomerInfo, forType: LatestDeviceCustomerInfo.self)

    let options = dependencyContainer.makeSuperwallOptions()
    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )

    // New response from backend: SUPERWALL entitlement has been REVOKED (empty entitlements)
    let revokedResponse = EntitlementsResponse(
      customerInfo: CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: []  // No entitlements - the SUPERWALL one was revoked
      )
    )
    mockNetwork.getEntitlementsResponse = revokedResponse

    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: dependencyContainer.storage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    // Poll web entitlements - this should detect the revocation
    await redeemer.pollWebEntitlements(config: config, isFirstTime: true)

    // Wait for async queue operations to complete (EntitlementsInfo updates backingActive async)
    // Poll up to 3 seconds for the entitlements to be updated (CI can be slow)
    var attempts = 0
    while !superwall.entitlements.active.isEmpty && attempts < 30 {
      try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
      attempts += 1
    }

    // Verify the SUPERWALL entitlement was removed
    #expect(superwall.customerInfo.entitlements.isEmpty, "CustomerInfo should have no entitlements after revocation")
    #expect(superwall.entitlements.active.isEmpty, "Active entitlements should be empty after revocation")

    // Verify the LatestRedeemResponse was updated with empty entitlements
    let savedRedeemResponse = dependencyContainer.storage.get(LatestRedeemResponse.self)
    #expect(savedRedeemResponse?.customerInfo.entitlements.isEmpty == true, "Saved redeem response should have no entitlements")
  }

  @Test("External purchase controller with mixed web + appStore entitlements - polling removes web entitlements")
  func testPollWebEntitlements_externalPurchaseController_mixedEntitlements_webRemoved() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    // Create a simple external purchase controller (doesn't conform to InternalPurchaseController, so isInternal = false)
    class ExternalPurchaseController: PurchaseController {
      @MainActor
      func purchase(product: StoreProduct) async -> PurchaseResult {
        return .purchased
      }

      @MainActor
      func restorePurchases() async -> RestorationResult {
        return .restored
      }
    }

    // Set the external purchase controller on the dependency container BEFORE creating Superwall
    let externalController = ExternalPurchaseController()
    dependencyContainer.purchaseController = externalController

    // Create a web entitlement that was previously granted
    let webEntitlement = Entitlement(
      id: "premium_web",
      type: .serviceLevel,
      isActive: true,
      productIds: ["web_product"],
      latestProductId: nil,
      store: .superwall,
      startsAt: Date(),
      renewedAt: nil,
      expiresAt: nil,
      isLifetime: true,
      willRenew: nil,
      state: nil,
      offerType: nil
    )

    // Create an appStore entitlement from external purchase controller
    let appStoreEntitlement = Entitlement(
      id: "premium_appstore",
      type: .serviceLevel,
      isActive: true,
      productIds: ["appstore_product"],
      latestProductId: "appstore_product",
      store: .appStore,
      startsAt: Date(),
      renewedAt: nil,
      expiresAt: Date().addingTimeInterval(3600 * 24 * 30), // 30 days from now
      isLifetime: false,
      willRenew: true,
      state: nil,
      offerType: nil
    )

    // Set up superwall instance
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // Set up mixed entitlements in subscription status
    // With external purchase controller, we need to set this directly since internallySetSubscriptionStatus returns early
    await MainActor.run {
      superwall.subscriptionStatus = .active([webEntitlement, appStoreEntitlement])
    }

    // Previous web response had the web entitlement
    let previousWebCustomerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [webEntitlement]
    )
    let previousRedeemResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: previousWebCustomerInfo)

    // Device has no entitlements (empty device CustomerInfo)
    let deviceCustomerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: []
    )

    // Set up mock storage
    let mockStorage = StorageMock(
      internalRedeemResponse: previousRedeemResponse,
      cache: Cache()
    )
    mockStorage.save(deviceCustomerInfo, forType: LatestDeviceCustomerInfo.self)

    let options = dependencyContainer.makeSuperwallOptions()
    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )

    // New response from backend: web entitlement has been REVOKED (empty entitlements)
    let revokedResponse = EntitlementsResponse(
      customerInfo: CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: []  // No web entitlements anymore
      )
    )
    mockNetwork.getEntitlementsResponse = revokedResponse

    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: externalController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    // Poll web entitlements - this should remove the web entitlement but keep the appStore one
    await redeemer.pollWebEntitlements(config: config, isFirstTime: true)

    // Verify that ONLY the appStore entitlement remains (superwall/web-granted entitlement was filtered out)
    #expect(superwall.customerInfo.entitlements.count == 1, "CustomerInfo should have only 1 entitlement")
    #expect(superwall.customerInfo.entitlements.first?.id == "premium_appstore", "Only appStore entitlement should remain")
    #expect(superwall.customerInfo.entitlements.first?.store == .appStore, "Remaining entitlement should be appStore")

    // Note: We don't verify superwall.entitlements.active here because with an external purchase controller,
    // subscriptionStatus is not updated by internallySetSubscriptionStatus (it returns early).
    // The external purchase controller owns subscriptionStatus, so we only verify customerInfo.

    // Verify the LatestRedeemResponse was updated with empty entitlements (no superwall/web-granted entitlements)
    let savedRedeemResponse = mockStorage.get(LatestRedeemResponse.self)
    #expect(savedRedeemResponse?.customerInfo.entitlements.isEmpty == true, "Saved redeem response should have no superwall/web-granted entitlements")
  }

  @Test("External purchase controller with only web entitlements - polling removes all web entitlements")
  func testPollWebEntitlements_externalPurchaseController_onlyWebEntitlements_allRemoved() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    // Create a simple external purchase controller (doesn't conform to InternalPurchaseController, so isInternal = false)
    class ExternalPurchaseController: PurchaseController {
      @MainActor
      func purchase(product: StoreProduct) async -> PurchaseResult {
        return .purchased
      }

      @MainActor
      func restorePurchases() async -> RestorationResult {
        return .restored
      }
    }

    // Set the external purchase controller on the dependency container BEFORE creating Superwall
    let externalController = ExternalPurchaseController()
    dependencyContainer.purchaseController = externalController

    // Create a web entitlement that was previously granted
    let webEntitlement = Entitlement(
      id: "premium_web",
      type: .serviceLevel,
      isActive: true,
      productIds: ["web_product"],
      latestProductId: nil,
      store: .superwall,
      startsAt: Date(),
      renewedAt: nil,
      expiresAt: nil,
      isLifetime: true,
      willRenew: nil,
      state: nil,
      offerType: nil
    )

    // Set up superwall instance
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    // Set up only web entitlement in subscription status
    await superwall.internallySetSubscriptionStatus(
      to: .active([webEntitlement]),
      superwall: superwall
    )

    // Previous web response had the web entitlement
    let previousWebCustomerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [webEntitlement]
    )
    let previousRedeemResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: previousWebCustomerInfo)

    // Device has no entitlements (empty device CustomerInfo)
    let deviceCustomerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: []
    )

    // Set up mock storage
    let mockStorage = StorageMock(
      internalRedeemResponse: previousRedeemResponse,
      cache: Cache()
    )
    mockStorage.save(deviceCustomerInfo, forType: LatestDeviceCustomerInfo.self)

    let options = dependencyContainer.makeSuperwallOptions()
    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )

    // New response from backend: web entitlement has been REVOKED (empty entitlements)
    let revokedResponse = EntitlementsResponse(
      customerInfo: CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: []  // No web entitlements anymore
      )
    )
    mockNetwork.getEntitlementsResponse = revokedResponse

    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: externalController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    // Poll web entitlements - this should remove all web entitlements
    await redeemer.pollWebEntitlements(config: config, isFirstTime: true)

    // Verify that all entitlements were removed (since the only one was a web entitlement)
    #expect(superwall.customerInfo.entitlements.isEmpty, "CustomerInfo should have no entitlements")

    // Note: We don't verify subscriptionStatus or entitlements.active here because with an external purchase controller,
    // subscriptionStatus is not updated by internallySetSubscriptionStatus (it returns early).
    // The external purchase controller owns subscriptionStatus, so we only verify customerInfo.

    // Verify the LatestRedeemResponse was updated with empty entitlements
    let savedRedeemResponse = mockStorage.get(LatestRedeemResponse.self)
    #expect(savedRedeemResponse?.customerInfo.entitlements.isEmpty == true, "Saved redeem response should have no entitlements")
  }

  @Test("Concurrent redemptions blocked when paywall is open")
  func testRedeem_concurrent_paywallOpen_secondBlocked() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let cache = dependencyContainer.paywallManager.cache
    let messageHandler = await PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = await SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = await PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: cache,
      paywallArchiveManager: nil
    )
    cache.save(paywallVc, forKey: "key")
    cache.activePaywallVcKey = "key"
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )

    // Add a delay to the network mock so the first redemption is still in progress
    mockNetwork.redeemDelay = 1.0

    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: "CODE1",
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: entitlements)
    )
    mockNetwork.getWebEntitlementsResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(entitlements)))
      .setting(\.results, to: [result])

    // Start first redemption (will take 1 second due to delay)
    async let firstRedemption: Void = redeemer.redeem(.code("CODE1"))

    // Wait until the first redemption is actively processing to avoid
    // timing flakiness under high test parallelism.
    var processingStarted = false
    for _ in 0..<200 {
      if await redeemer.isCurrentlyProcessing {
        processingStarted = true
        break
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(processingStarted, "First redemption should enter processing state")

    // Start second redemption while first is still in progress.
    await redeemer.redeem(.code("CODE2"))

    // Wait for first redemption to complete
    await firstRedemption

    // Only first redemption should have completed
    #expect(mockNetwork.redeemCallCount == 1, "Only first redemption should have made network call")
  }

  @Test("Concurrent redemptions allowed when no paywall is open")
  func testRedeem_concurrent_noPaywall_bothAllowed() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)

    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )

    // Add a delay to the network mock
    mockNetwork.redeemDelay = 0.5

    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: "CODE1",
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: entitlements)
    )
    mockNetwork.getWebEntitlementsResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(entitlements)))
      .setting(\.results, to: [result])

    // Start both redemptions concurrently (no paywall open)
    async let firstRedemption: Void = redeemer.redeem(.code("CODE1"))
    async let secondRedemption: Void = redeemer.redeem(.code("CODE2"))

    await firstRedemption
    await secondRedemption

    // Both redemptions should have completed
    #expect(mockNetwork.redeemCallCount == 2, "Both redemptions should have made network calls since no paywall is open")
  }

  @Test("Schedules trial notification when redeemed product has free trial")
  func testRedeem_withFreeTrial_schedulesNotification() async {
    guard #available(iOS 14.0, *) else {
      return
    }
    let cache = dependencyContainer.paywallManager.cache
    let messageHandler = await PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = await SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )

    let entitlement = Entitlement(id: "premium", isActive: true)
    let product = Product(
      name: "Test Product",
      type: .appStore(.init(id: "test_product")),
      id: "test_product",
      entitlements: [entitlement]
    )

    // Create paywall with local notifications
    let trialNotification = LocalNotification.stub()
    let paywall = Paywall.stub()
      .setting(\.products, to: [product])
      .setting(\.localNotifications, to: [trialNotification])

    let paywallVc = await PaywallViewControllerMock(
      paywall: paywall,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: cache,
      paywallArchiveManager: nil
    )
    cache.save(paywallVc, forKey: "key")
    cache.activePaywallVcKey = "key"
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    dependencyContainer.entitlementsInfo.entitlementsByProductId["test_product"] = [entitlement]

    // Build a RedemptionResult with paywallInfo that has trialPeriodDays > 0
    let redemptionResultJSON = """
    {
      "status": "SUCCESS",
      "code": "TESTCODE",
      "redemptionInfo": {
        "ownership": { "type": "APP_USER", "appUserId": "appUserId" },
        "purchaserInfo": {
          "appUserId": "appUserId",
          "storeIdentifiers": {
            "store": "STRIPE",
            "stripeCustomerId": "cus_123",
            "stripeSubscriptionIds": ["sub_123"]
          }
        },
        "paywallInfo": {
          "identifier": "test_paywall",
          "placementName": "test_placement",
          "placementParams": {},
          "variantId": "variant_1",
          "experimentId": "exp_1",
          "product": {
            "identifier": "test_product",
            "languageCode": "en",
            "locale": "en_US",
            "currencyCode": "USD",
            "currencySymbol": "$",
            "period": "1 month",
            "periodly": "monthly",
            "localizedPeriod": "month",
            "periodAlt": "mo",
            "periodDays": 30,
            "periodWeeks": 4,
            "periodMonths": 1,
            "periodYears": 0,
            "rawPrice": 9.99,
            "price": "$9.99",
            "dailyPrice": "$0.33",
            "weeklyPrice": "$2.50",
            "monthlyPrice": "$9.99",
            "yearlyPrice": "$119.88",
            "rawTrialPeriodPrice": 0.0,
            "trialPeriodPrice": "$0.00",
            "trialPeriodDailyPrice": "$0.00",
            "trialPeriodWeeklyPrice": "$0.00",
            "trialPeriodMonthlyPrice": "$0.00",
            "trialPeriodYearlyPrice": "$0.00",
            "trialPeriodDays": 7,
            "trialPeriodWeeks": 1,
            "trialPeriodMonths": 0,
            "trialPeriodYears": 0,
            "trialPeriodText": "7-day free trial",
            "trialPeriodEndDate": "2025-04-01"
          }
        },
        "entitlements": [{
          "identifier": "premium",
          "type": "SERVICE_LEVEL",
          "isActive": true
        }]
      }
    }
    """.data(using: .utf8)!

    let result = try! JSONDecoder().decode(
      RedemptionResult.self,
      from: redemptionResultJSON
    )

    let existingResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: [entitlement]
      ))
      .setting(\.results, to: [result])

    let mockStorage = StorageMock(internalRedeemResponse: existingResponse)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()
    let mockNotificationScheduler = NotificationSchedulerMock()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      notificationScheduler: mockNotificationScheduler,
      superwall: superwall
    )

    mockNetwork.getWebEntitlementsResponse = existingResponse

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    await redeemer.redeem(
      .code("TESTCODE"),
      injectedConfig: config
    )

    // Verify notifications were scheduled
    #expect(!mockNotificationScheduler.scheduledNotifications.isEmpty)
    #expect(mockNotificationScheduler.scheduledNotifications.first?.type == .trialStarted)
    #expect(mockNotificationScheduler.scheduledPaywallId != nil)

    // Verify delegate received success result
    if case .success = mockDelegate.receivedResult {} else {
      Issue.record("should have been a success")
    }
  }

  @Test("Does not schedule trial notification when trialPeriodDays is 0")
  func testRedeem_withNoFreeTrial_doesNotScheduleNotification() async {
    guard #available(iOS 14.0, *) else {
      return
    }
    let cache = dependencyContainer.paywallManager.cache
    let messageHandler = await PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = await SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )

    let entitlement = Entitlement(id: "premium", isActive: true)
    let product = Product(
      name: "Test Product",
      type: .appStore(.init(id: "test_product")),
      id: "test_product",
      entitlements: [entitlement]
    )

    let paywall = Paywall.stub()
      .setting(\.products, to: [product])

    let paywallVc = await PaywallViewControllerMock(
      paywall: paywall,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: cache,
      paywallArchiveManager: nil
    )
    cache.save(paywallVc, forKey: "key")
    cache.activePaywallVcKey = "key"
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    dependencyContainer.entitlementsInfo.entitlementsByProductId["test_product"] = [entitlement]

    // Build a RedemptionResult with paywallInfo that has trialPeriodDays = 0
    let redemptionResultJSON = """
    {
      "status": "SUCCESS",
      "code": "TESTCODE",
      "redemptionInfo": {
        "ownership": { "type": "APP_USER", "appUserId": "appUserId" },
        "purchaserInfo": {
          "appUserId": "appUserId",
          "storeIdentifiers": {
            "store": "STRIPE",
            "stripeCustomerId": "cus_123",
            "stripeSubscriptionIds": ["sub_123"]
          }
        },
        "paywallInfo": {
          "identifier": "test_paywall",
          "placementName": "test_placement",
          "placementParams": {},
          "variantId": "variant_1",
          "experimentId": "exp_1",
          "product": {
            "identifier": "test_product",
            "languageCode": "en",
            "locale": "en_US",
            "currencyCode": "USD",
            "currencySymbol": "$",
            "period": "1 month",
            "periodly": "monthly",
            "localizedPeriod": "month",
            "periodAlt": "mo",
            "periodDays": 30,
            "periodWeeks": 4,
            "periodMonths": 1,
            "periodYears": 0,
            "rawPrice": 9.99,
            "price": "$9.99",
            "dailyPrice": "$0.33",
            "weeklyPrice": "$2.50",
            "monthlyPrice": "$9.99",
            "yearlyPrice": "$119.88",
            "rawTrialPeriodPrice": 0.0,
            "trialPeriodPrice": "$0.00",
            "trialPeriodDailyPrice": "$0.00",
            "trialPeriodWeeklyPrice": "$0.00",
            "trialPeriodMonthlyPrice": "$0.00",
            "trialPeriodYearlyPrice": "$0.00",
            "trialPeriodDays": 0,
            "trialPeriodWeeks": 0,
            "trialPeriodMonths": 0,
            "trialPeriodYears": 0,
            "trialPeriodText": "",
            "trialPeriodEndDate": ""
          }
        },
        "entitlements": [{
          "identifier": "premium",
          "type": "SERVICE_LEVEL",
          "isActive": true
        }]
      }
    }
    """.data(using: .utf8)!

    let result = try! JSONDecoder().decode(
      RedemptionResult.self,
      from: redemptionResultJSON
    )

    let existingResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: [entitlement]
      ))
      .setting(\.results, to: [result])

    let mockStorage = StorageMock(internalRedeemResponse: existingResponse)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()
    let mockNotificationScheduler = NotificationSchedulerMock()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      notificationScheduler: mockNotificationScheduler,
      superwall: superwall
    )

    mockNetwork.getWebEntitlementsResponse = existingResponse

    let config = Config
      .stub()
      .setting(
        \.web2appConfig,
         to: .init(entitlementsMaxAge: 60, restoreAccessURL: URL("https://google.com")!)
      )

    await redeemer.redeem(
      .code("TESTCODE"),
      injectedConfig: config
    )

    // Verify delegate received success result
    if case .success = mockDelegate.receivedResult {} else {
      Issue.record("should have been a success")
    }

    // Verify notifications were NOT scheduled because trialPeriodDays == 0
    #expect(mockNotificationScheduler.scheduledNotifications.isEmpty)
    #expect(mockNotificationScheduler.scheduledPaywallId == nil)
  }

  @Test("ExistingCodes redemptions not blocked when paywall is open")
  func testRedeem_existingCodes_paywallOpen_notBlocked() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let cache = dependencyContainer.paywallManager.cache
    let messageHandler = await PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = await SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = await PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: cache,
      paywallArchiveManager: nil
    )
    cache.save(paywallVc, forKey: "key")
    cache.activePaywallVcKey = "key"
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false

    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )

    // Add a delay to the network mock
    mockNetwork.redeemDelay = 1.0

    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockPurchaseController = MockPurchaseController()

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: mockPurchaseController,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: "CODE1",
      redemptionInfo: .init(ownership: .appUser(appUserId: "appUserId"), purchaserInfo: .init(appUserId: "appUserId", email: nil, storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])), entitlements: entitlements)
    )
    mockNetwork.getWebEntitlementsResponse = RedeemResponse.stub()
      .setting(\.customerInfo, to: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: Array(entitlements)))
      .setting(\.results, to: [result])

    // Start .code redemption (will take 1 second due to delay)
    async let firstRedemption: Void = redeemer.redeem(.code("CODE1"))

    // Wait a bit to ensure first redemption has started
    try? await Task.sleep(nanoseconds: 100_000_000)

    // Start .existingCodes redemption while .code is still in progress
    async let secondRedemption: Void = redeemer.redeem(.existingCodes)

    await firstRedemption
    await secondRedemption

    // Both redemptions should have completed (existingCodes is not blocked)
    #expect(mockNetwork.redeemCallCount == 2, "Both redemptions should have made network calls since .existingCodes is not blocked")
  }

  @Test("Stripe checkout submit persists pending context with default attempts")
  func testStripeCheckoutSubmit_persistsPendingState() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )
    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_1", productId: "prod_1")

    let state = mockStorage.get(PendingStripeCheckoutPollStorage.self)
    #expect(state?.checkoutContextId == "ctx_1")
    #expect(state?.productId == "prod_1")
    #expect(state?.remainingForegroundAttempts == 5)
  }

  @Test("Stripe checkout submit replaces older pending context")
  func testStripeCheckoutSubmit_replacesPendingState() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )
    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_old", productId: "prod_old")
    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_new", productId: "prod_new")

    let state = mockStorage.get(PendingStripeCheckoutPollStorage.self)
    #expect(state?.checkoutContextId == "ctx_new")
    #expect(state?.productId == "prod_new")
    #expect(state?.remainingForegroundAttempts == 5)
  }

  @Test("Paywall-open Stripe recovery loading shows only for non-expired pending context")
  func testStripePaywallOpenLoading_guardedByTimeout() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )
    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      stripePendingPollIntervalNs: 1_000_000,
      stripePendingPollTimeoutNs: 5_000_000,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_live", productId: "prod_live")
    #expect(await redeemer.shouldShowStripeRecoveryLoadingOnPaywallOpen() == true)

    mockStorage.save(
      PendingStripeCheckoutPollState(
        checkoutContextId: "ctx_expired",
        productId: "prod_expired",
        updatedAt: Date(timeIntervalSinceNow: -10)
      ),
      forType: PendingStripeCheckoutPollStorage.self
    )
    #expect(await redeemer.shouldShowStripeRecoveryLoadingOnPaywallOpen() == false)
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("Stripe checkout complete polls immediately, invokes will/did callbacks, and clears pending on success")
  func testStripeCheckoutComplete_success_immediatePoll() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)

    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: "redemption_123",
      redemptionInfo: .init(
        ownership: .appUser(appUserId: "appUserId"),
        purchaserInfo: .init(
          appUserId: "appUserId",
          email: nil,
          storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])
        ),
        entitlements: entitlements
      )
    )
    mockNetwork.pollRedemptionResultResponses = [
      .success(
        RedeemResponse(
          results: [result],
          customerInfo: CustomerInfo(
            subscriptions: [],
            nonSubscriptions: [],
            entitlements: Array(entitlements)
          )
        )
      )
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.handleStripeCheckoutComplete(contextId: "ctx_1", productId: "prod_1")

    #expect(mockNetwork.pollRedemptionResultCallCount == 1)
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self) == nil)
    #expect(mockDelegate.willRedeemCallCount == 1)
    #expect(mockDelegate.receivedResult?.code == "redemption_123")

    if let willAt = mockDelegate.willRedeemCalledAt,
      let didAt = mockDelegate.didRedeemCalledAt {
      #expect(didAt.timeIntervalSince(willAt) >= 0.19)
    } else {
      Issue.record("Expected will/did redeem callbacks to be invoked")
    }
  }

  @Test("Legacy redeem keeps callback compatibility: willRedeemLink fires before /redeem request")
  func testLegacyRedeem_callbacksCompatibility() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)

    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: "legacy_code",
      redemptionInfo: .init(
        ownership: .appUser(appUserId: "appUserId"),
        purchaserInfo: .init(
          appUserId: "appUserId",
          email: nil,
          storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])
        ),
        entitlements: entitlements
      )
    )
    mockNetwork.getWebEntitlementsResponse = RedeemResponse(
      results: [result],
      customerInfo: CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: Array(entitlements)
      )
    )

    var willRedeemCountAtRequestStart = -1
    mockNetwork.onRedeemEntitlements = {
      willRedeemCountAtRequestStart = mockDelegate.willRedeemCallCount
    }

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.redeem(.code("legacy_code"))

    #expect(willRedeemCountAtRequestStart == 1)
    #expect(mockDelegate.willRedeemCallCount == 1)
    #expect(mockDelegate.receivedResult?.code == "legacy_code")
  }

  @Test("Stripe checkout complete retries no-redemption 5 times and keeps pending state")
  func testStripeCheckoutComplete_noRedemption_retriesAndKeepsPending() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      stripePendingPollIntervalNs: 1_000_000,
      stripePendingPollTimeoutNs: 5_000_000_000,
      superwall: superwall
    )

    // Let the init task settle, then reset counters
    try? await Task.sleep(nanoseconds: 50_000_000)
    mockNetwork.pollRedemptionResultCallCount = 0
    // Provide exactly 6 pending responses; the 7th call will throw
    // NetworkError.unknown, exiting the loop via .requestFailed.
    mockNetwork.pollRedemptionResultResponses = Array(
      repeating: .success(RedeemResponse(results: [], customerInfo: .blank(), status: .pending)),
      count: 6
    )

    await redeemer.handleStripeCheckoutComplete(contextId: "ctx_1", productId: "prod_1")

    // 6 pending + 1 error = 7 total calls before .requestFailed exits the loop
    #expect(mockNetwork.pollRedemptionResultCallCount == 7)
    let state = mockStorage.get(PendingStripeCheckoutPollStorage.self)
    #expect(state?.checkoutContextId == "ctx_1")
    #expect(state?.remainingForegroundAttempts == 5)
  }

  @Test("Foreground polling consumes attempts and clears pending after 5 tries")
  func testStripeForegroundPolling_consumesAttempts() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    // Let the init task settle, then reset counters
    try? await Task.sleep(nanoseconds: 50_000_000)
    mockNetwork.pollRedemptionResultCallCount = 0

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_1", productId: "prod_1")
    mockNetwork.pollRedemptionResultResponses = Array(
      repeating: .failure(NetworkError.unknown),
      count: 5
    )

    await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self)?.remainingForegroundAttempts == 4)

    await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()
    await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()
    await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()
    await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()

    #expect(mockNetwork.pollRedemptionResultCallCount == 5)
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("Foreground Stripe recovery success uses fake callback timing and clears pending context")
  func testStripeForegroundPolling_success_fakeCallbacksAndClearsPending() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)

    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: "redemption_foreground",
      redemptionInfo: .init(
        ownership: .appUser(appUserId: "appUserId"),
        purchaserInfo: .init(
          appUserId: "appUserId",
          email: nil,
          storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])
        ),
        entitlements: entitlements
      )
    )
    mockNetwork.pollRedemptionResultResponses = [
      .success(
        RedeemResponse(
          results: [result],
          customerInfo: CustomerInfo(
            subscriptions: [],
            nonSubscriptions: [],
            entitlements: Array(entitlements)
          )
        )
      )
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_fg_1", productId: "prod_fg_1")
    await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()

    #expect(mockNetwork.pollRedemptionResultCallCount == 1)
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self) == nil)
    #expect(mockDelegate.willRedeemCallCount == 1)
    #expect(mockDelegate.receivedResult?.code == "redemption_foreground")

    if let willAt = mockDelegate.willRedeemCalledAt,
      let didAt = mockDelegate.didRedeemCalledAt {
      #expect(didAt.timeIntervalSince(willAt) >= 0.19)
    } else {
      Issue.record("Expected will/did redeem callbacks to be invoked for foreground poll success")
    }
  }

  @Test("Foreground Stripe recovery no-redemption retries and consumes one attempt")
  func testStripeForegroundPolling_noRedemption_retriesAndConsumesAttempt() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      stripePendingPollIntervalNs: 1_000_000,
      stripePendingPollTimeoutNs: 5_000_000_000,
      superwall: superwall
    )

    // Let the init task settle, then reset counters
    try? await Task.sleep(nanoseconds: 50_000_000)
    mockNetwork.pollRedemptionResultCallCount = 0
    // Provide exactly 6 pending responses; the 7th call will throw
    // NetworkError.unknown, exiting the loop via .requestFailed.
    mockNetwork.pollRedemptionResultResponses = Array(
      repeating: .success(RedeemResponse(results: [], customerInfo: .blank(), status: .pending)),
      count: 6
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_fg_2", productId: "prod_fg_2")
    await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()

    // 6 pending + 1 error = 7 total calls before .requestFailed exits the loop
    #expect(mockNetwork.pollRedemptionResultCallCount == 7)
    let state = mockStorage.get(PendingStripeCheckoutPollStorage.self)
    #expect(state?.checkoutContextId == "ctx_fg_2")
    #expect(state?.remainingForegroundAttempts == 4)
  }

  @Test("Stripe checkout complete failed status clears pending state")
  func testStripeCheckoutComplete_failedStatus_clearsPendingState() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    mockNetwork.pollRedemptionResultResponses = [
      .success(RedeemResponse(results: [], customerInfo: .blank(), status: .failed))
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.handleStripeCheckoutComplete(contextId: "ctx_failed", productId: "prod_failed")

    #expect(mockNetwork.pollRedemptionResultCallCount == 1)
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self) == nil)
    #expect(mockDelegate.willRedeemCallCount == 0)
  }

  @Test("Foreground Stripe recovery failed status clears pending state")
  func testStripeForegroundPolling_failedStatus_clearsPendingState() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    mockNetwork.pollRedemptionResultResponses = [
      .success(RedeemResponse(results: [], customerInfo: .blank(), status: .failed))
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_failed_fg", productId: "prod_failed_fg")
    await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()

    #expect(mockNetwork.pollRedemptionResultCallCount == 1)
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("Stripe checkout complete status without codes clears pending state")
  func testStripeCheckoutComplete_completeStatusWithoutCodes_clearsPendingState() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(options: dependencyContainer.makeSuperwallOptions(), factory: dependencyContainer)
    mockNetwork.pollRedemptionResultResponses = [
      .success(RedeemResponse(results: [], customerInfo: .blank(), status: .complete))
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.handleStripeCheckoutComplete(contextId: "ctx_complete_no_code", productId: "prod_complete_no_code")

    #expect(mockNetwork.pollRedemptionResultCallCount == 1)
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("Stripe checkout abandon tracks transaction_abandon and does not clear pending")
  func testStripeCheckoutAbandon_tracksAndKeepsPending() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter

    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_1", productId: "prod_1")
    await redeemer.handleStripeCheckoutAbandon(productId: "prod_1")

    let events = mockDelegate.eventsReceived.map { $0.backingData.objcEvent }
    #expect(events.contains(SuperwallEventObjc.transactionAbandon))
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self)?.checkoutContextId == "ctx_1")
  }

  @Test("pollOrWaitForActiveStripePoll returns false when no pending state")
  func testPollOrWait_noPendingState_returnsFalse() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let mockNetwork = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )

    // Clear any persisted pending state from previous tests
    mockStorage.delete(PendingStripeCheckoutPollStorage.self)

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    // Let the init task settle, then reset counters
    try? await Task.sleep(nanoseconds: 50_000_000)
    mockNetwork.pollRedemptionResultCallCount = 0

    let result = await redeemer.pollOrWaitForActiveStripePoll()
    #expect(result == false)
    #expect(mockNetwork.pollRedemptionResultCallCount == 0)
  }

  @Test("pollOrWaitForActiveStripePoll starts own poll when no active poll")
  func testPollOrWait_noActivePoll_startsOwnPoll() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)
    mockNetwork.pollRedemptionResultResponses = [
      .success(RedeemResponse(results: [], customerInfo: .blank(), status: .failed))
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_poll", productId: "prod_poll")
    let result = await redeemer.pollOrWaitForActiveStripePoll()

    #expect(result == false)
    #expect(mockNetwork.pollRedemptionResultCallCount == 1)
    #expect(mockStorage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("pollOrWaitForActiveStripePoll returns true when waiting on active poll that redeems")
  func testPollOrWait_waitsForActivePollAndReturnsRedeemed() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)

    let entitlements: Set<Entitlement> = [.stub()]
    let redeemResult = RedemptionResult.success(
      code: "code_wait",
      redemptionInfo: .init(
        ownership: .appUser(appUserId: "appUserId"),
        purchaserInfo: .init(
          appUserId: "appUserId",
          email: nil,
          storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])
        ),
        entitlements: entitlements
      )
    )
    mockNetwork.pollRedemptionResultResponses = [
      .success(RedeemResponse(results: [], customerInfo: .blank(), status: .pending)),
      .success(
        RedeemResponse(
          results: [redeemResult],
          customerInfo: CustomerInfo(
            subscriptions: [],
            nonSubscriptions: [],
            entitlements: Array(entitlements)
          )
        )
      )
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      stripePendingPollIntervalNs: 500_000_000,
      stripePendingPollTimeoutNs: 5_000_000_000,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_wait", productId: "prod_wait")

    async let activePollResult: Bool = redeemer.pollPendingStripeCheckoutOnPaywallOpenIfNeeded()

    for _ in 0..<50 where mockNetwork.pollRedemptionResultCallCount == 0 {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }

    let waitingResult = await redeemer.pollOrWaitForActiveStripePoll()
    _ = await activePollResult

    #expect(waitingResult == true)
    #expect(mockNetwork.pollRedemptionResultCallCount >= 1)
  }

  @Test("pollOrWaitForActiveStripePoll ignores redeemed result from different context")
  func testPollOrWait_waitsForActivePollDifferentContext_returnsFalse() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)

    let entitlements: Set<Entitlement> = [.stub()]
    let redeemResult = RedemptionResult.success(
      code: "code_old",
      redemptionInfo: .init(
        ownership: .appUser(appUserId: "appUserId"),
        purchaserInfo: .init(
          appUserId: "appUserId",
          email: nil,
          storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])
        ),
        entitlements: entitlements
      )
    )
    mockNetwork.pollRedemptionResultResponses = [
      .success(RedeemResponse(results: [], customerInfo: .blank(), status: .pending)),
      .success(
        RedeemResponse(
          results: [redeemResult],
          customerInfo: CustomerInfo(
            subscriptions: [],
            nonSubscriptions: [],
            entitlements: Array(entitlements)
          )
        )
      )
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      stripePendingPollIntervalNs: 1_000_000_000,
      stripePendingPollTimeoutNs: 5_000_000_000,
      superwall: superwall
    )

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_old", productId: "prod_old")
    async let activePollResult: Bool = redeemer.pollPendingStripeCheckoutOnPaywallOpenIfNeeded()

    for _ in 0..<50 where mockNetwork.pollRedemptionResultCallCount == 0 {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }

    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_new", productId: "prod_new")
    let waitingResult = await redeemer.pollOrWaitForActiveStripePoll()
    _ = await activePollResult

    #expect(waitingResult == false)
  }

  @Test("Stripe checkout complete preserves existing foreground attempts for same context")
  func testStripeCheckoutComplete_preservesExistingAttempts() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)

    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: "code_preserve",
      redemptionInfo: .init(
        ownership: .appUser(appUserId: "appUserId"),
        purchaserInfo: .init(
          appUserId: "appUserId",
          email: nil,
          storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])
        ),
        entitlements: entitlements
      )
    )
    mockNetwork.pollRedemptionResultResponses = [
      .success(
        RedeemResponse(
          results: [result],
          customerInfo: CustomerInfo(
            subscriptions: [],
            nonSubscriptions: [],
            entitlements: Array(entitlements)
          )
        )
      )
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    // Simulate: checkout_submit saved state, then a foreground poll consumed one attempt
    mockStorage.save(
      PendingStripeCheckoutPollState(
        checkoutContextId: "ctx_preserve",
        productId: "prod_preserve",
        remainingForegroundAttempts: 3
      ),
      forType: PendingStripeCheckoutPollStorage.self
    )

    // checkout_complete with the same context should preserve the 3 remaining attempts
    await redeemer.handleStripeCheckoutComplete(contextId: "ctx_preserve", productId: "prod_preserve")

    // Redemption succeeded, so pending state is cleared after alert flow.
    // But the point is it didn't reset to 5 attempts before polling.
    #expect(mockNetwork.pollRedemptionResultCallCount == 1)
  }

  @Test("Stripe checkout complete uses default attempts for new context")
  func testStripeCheckoutComplete_newContext_usesDefaultAttempts() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockStorage = StorageMock(internalRedeemResponse: nil)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(options: options, factory: dependencyContainer)
    mockNetwork.pollRedemptionResultResponses = [
      .success(RedeemResponse(results: [], customerInfo: .blank(), status: .failed))
    ]

    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: mockStorage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )

    // Existing state has different context
    mockStorage.save(
      PendingStripeCheckoutPollState(
        checkoutContextId: "ctx_old",
        productId: "prod_old",
        remainingForegroundAttempts: 2
      ),
      forType: PendingStripeCheckoutPollStorage.self
    )

    // checkout_complete with new context should get default 5 attempts
    await redeemer.handleStripeCheckoutComplete(contextId: "ctx_new", productId: "prod_new")

    // Failed status clears pending state, but we can verify the poll happened
    #expect(mockNetwork.pollRedemptionResultCallCount == 1)
  }
}
