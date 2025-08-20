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
    mockNetwork.redeemEntitlementsResponse = RedeemResponse.stub()
      .setting(\.entitlements, to: entitlements)
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
      .setting(\.entitlements, to: existingEntitlements)
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
    mockNetwork.redeemEntitlementsResponse = RedeemResponse.stub()
      .setting(\.entitlements, to: entitlements)
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
    let paywallVc = await PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      webView: webView,
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
      .setting(\.entitlements, to: existingEntitlements)
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
    mockNetwork.redeemEntitlementsResponse = RedeemResponse.stub()
      .setting(\.entitlements, to: entitlements)
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
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      webView: webView,
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
      .setting(\.entitlements, to: existingEntitlements)
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

    try? await Task.sleep(for: .milliseconds(300))
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
//    mockNetwork.redeemEntitlementsResponse = RedeemResponse.mock()
//
//    await redeemer.redeem(.existingCodes)
//
//    #expect(mockNetwork.didRedeemEntitlements)
//    let savedResponse = mockStorage.savedObjects[LatestRedeemResponse.self] as? LatestRedeemResponse
//    #expect(savedResponse != nil)
//  }
}
