//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 31/03/2025.
//

import Testing
@testable import SuperwallKit
import Foundation

struct WebEntitlementRedeemerTests {
  let dependencyContainer = DependencyContainer()

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
      factory: dependencyContainer
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
      factory: dependencyContainer
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

    // Set up mock storage with both previous web response and device customer info
    let mockStorage = StorageMock(
      internalRedeemResponse: previousRedeemResponse,
      cache: Cache()
    )
    // Manually set the device CustomerInfo in storage
    mockStorage.save(deviceCustomerInfo, forType: LatestDeviceCustomerInfo.self)

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
      storage: mockStorage,
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
    // Poll up to 1 second for the entitlements to be updated
    var attempts = 0
    while !superwall.entitlements.active.isEmpty && attempts < 10 {
      try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
      attempts += 1
    }

    // Verify the SUPERWALL entitlement was removed
    #expect(superwall.customerInfo.entitlements.isEmpty, "CustomerInfo should have no entitlements after revocation")
    #expect(superwall.entitlements.active.isEmpty, "Active entitlements should be empty after revocation")

    // Verify the LatestRedeemResponse was updated with empty entitlements
    let savedRedeemResponse = mockStorage.get(LatestRedeemResponse.self)
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
      factory: dependencyContainer
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

    // Wait a bit to ensure first redemption has started
    try? await Task.sleep(nanoseconds: 100_000_000)

    // Start second redemption while first is still in progress
    let secondRedemptionStartTime = Date()
    await redeemer.redeem(.code("CODE2"))
    let secondRedemptionEndTime = Date()

    // Second redemption should return immediately (not wait for network)
    let secondRedemptionDuration = secondRedemptionEndTime.timeIntervalSince(secondRedemptionStartTime)
    #expect(secondRedemptionDuration < 0.5, "Second redemption should be blocked immediately, not wait for network")

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

  @Test("ExistingCodes redemptions not blocked when paywall is open")
  func testRedeem_existingCodes_paywallOpen_notBlocked() async {
    guard #available(iOS 14.0, *) else {
      return
    }

    let cache = dependencyContainer.paywallManager.cache
    let messageHandler = await PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer
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
}
