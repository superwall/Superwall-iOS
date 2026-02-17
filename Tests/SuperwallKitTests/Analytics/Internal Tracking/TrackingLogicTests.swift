//
//  InternalEventLogicTests.swift
//
//
//  Created by Yusuf Tör on 22/04/2022.
//
// swiftlint:disable all

import Testing
import Foundation

@testable import SuperwallKit

struct TrackingLogicTests {
  @Test func processParameters_superwallEvent_noParams() async {
    // Given
    let event = InternalSuperwallEvent.AppLaunch()

    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
  }
  /*
  func testProcessParameters_superwallEvent_noParams_firedTwice() {
    // Given
    let event = SuperwallEvent.AppLaunch()
    let storage = StorageMock(internalTriggeredEvents: [
      event.rawName: [.stub()]
    ])

    // When
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event,
      storage: storage
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.audienceFilterParams["$count_24h"] as! Int == 2)
  }*/

  @Test func processParameters_userEvent_noParams() async {
    // Given
    let event = UserInitiatedPlacement.Track(
      rawName: "test",
      canImplicitlyTriggerPaywall: false,
      isFeatureGatable: false
    )

    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(!(parameters.audienceFilterParams["$is_standard_event"] as! Bool))
    #expect(!(parameters.audienceFilterParams["$is_feature_gatable"] as! Bool))
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
  }
  /*
  func testProcessParameters_userEvent_noParams_firedTwice() {
    // Given
    let event = UserInitiatedPlacement.Track(
      rawName: "test",
      canImplicitlyTriggerPaywall: false
    )
    let storage = StorageMock(internalTriggeredEvents: [
      "test": [.stub()]
    ])

    // When
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event,
      storage: storage
    )

    #expect(!(parameters.audienceFilterParams["$is_standard_event"] as! Bool))
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.audienceFilterParams["$count_24h"] as! Int == 2)
  }
*/

  @Test func processParameters_paywallLoad() async {
    // Given
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      placementData:
        PlacementData
        .stub()
        .setting(\.name, to: eventName)
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.audienceFilterParams["$is_triggered_from_event"] as! Bool)
    #expect(
      parameters.audienceFilterParams["$event_name"] as! String == "paywallResponseLoad_start")
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.delegateParams["is_triggered_from_event"] as! Bool)
  }

  @Test func processParameters_attributes_withCustomParams() async {
    // Given
    let event = InternalSuperwallEvent.UserAttributes(
      appInstalledAtString: "abc",
      audienceFilterParams: [
        "myCustomParam": "hello",
        "otherParam": true,
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.audienceFilterParams["$application_installed_at"] as! String == "abc")
    #expect(parameters.audienceFilterParams["$event_name"] as! String == "user_attributes")
    #expect(parameters.audienceFilterParams["myCustomParam"] as! String == "hello")
    #expect(parameters.audienceFilterParams["otherParam"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.delegateParams["application_installed_at"] as! String == "abc")
    #expect(parameters.delegateParams["myCustomParam"] as! String == "hello")
    #expect(parameters.delegateParams["otherParam"] as! Bool)
  }

  @Test func processParameters_superwallEvent_customParams_containsDollar() async {
    // Given
    let event = InternalSuperwallEvent.UserAttributes(
      appInstalledAtString: "abc",
      audienceFilterParams: [
        "$myCustomParam": "hello",
        "otherParam": true,
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.audienceFilterParams["$application_installed_at"] as! String == "abc")
    #expect(parameters.audienceFilterParams["$event_name"] as! String == "user_attributes")
    #expect(parameters.audienceFilterParams["$myCustomParam"] == nil)
    #expect(parameters.audienceFilterParams["otherParam"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.delegateParams["application_installed_at"] as! String == "abc")
    #expect(parameters.delegateParams["$myCustomParam"] == nil)
    #expect(parameters.delegateParams["otherParam"] as! Bool)
  }

  @Test func processParameters_superwallEvent_customParams_containArray() async {
    // Given
    let event = InternalSuperwallEvent.UserAttributes(
      appInstalledAtString: "abc",
      audienceFilterParams: [
        "myCustomParam": ["hello"],
        "otherParam": true,
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.audienceFilterParams["$application_installed_at"] as! String == "abc")
    #expect(parameters.audienceFilterParams["$event_name"] as! String == "user_attributes")
    #expect(parameters.audienceFilterParams["myCustomParam"] == nil)
    #expect(parameters.audienceFilterParams["otherParam"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.delegateParams["application_installed_at"] as! String == "abc")
    #expect(parameters.delegateParams["myCustomParam"] == nil)
    #expect(parameters.delegateParams["otherParam"] as! Bool)
  }

  @Test func processParameters_superwallEvent_customParams_containDictionary() async {
    // Given
    let event = InternalSuperwallEvent.UserAttributes(
      appInstalledAtString: "abc",
      audienceFilterParams: [
        "myCustomParam": ["one": "two"],
        "otherParam": true,
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.audienceFilterParams["$application_installed_at"] as! String == "abc")
    #expect(parameters.audienceFilterParams["$event_name"] as! String == "user_attributes")
    #expect(parameters.audienceFilterParams["myCustomParam"] as! [String: String] == ["one": "two"])
    #expect(parameters.audienceFilterParams["otherParam"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.delegateParams["application_installed_at"] as! String == "abc")
    #expect(parameters.delegateParams["myCustomParam"] as! [String: String] == ["one": "two"])
    #expect(parameters.delegateParams["otherParam"] as! Bool)
  }

  @Test func processParameters_superwallEvent_customParams_containsDate() async {
    // Given
    let date = Date(timeIntervalSince1970: 1_650_534_735)
    let event = InternalSuperwallEvent.UserAttributes(
      appInstalledAtString: "abc",
      audienceFilterParams: [
        "myCustomParam": date,
        "otherParam": true,
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.audienceFilterParams["$application_installed_at"] as! String == "abc")
    #expect(parameters.audienceFilterParams["$event_name"] as! String == "user_attributes")
    #expect(parameters.audienceFilterParams["myCustomParam"] as! String == date.isoString)
    #expect(parameters.audienceFilterParams["otherParam"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.delegateParams["application_installed_at"] as! String == "abc")
    #expect(parameters.delegateParams["myCustomParam"] as! String == date.isoString)
    #expect(parameters.delegateParams["otherParam"] as! Bool)
  }

  @Test func processParameters_superwallEvent_customParams_containsUrl() async {
    // Given
    let url = URL(string: "https://www.google.com")!
    let event = InternalSuperwallEvent.UserAttributes(
      appInstalledAtString: "abc",
      audienceFilterParams: [
        "myCustomParam": url,
        "otherParam": true,
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.audienceFilterParams["$application_installed_at"] as! String == "abc")
    #expect(parameters.audienceFilterParams["$event_name"] as! String == "user_attributes")
    #expect(parameters.audienceFilterParams["myCustomParam"] as! String == url.absoluteString)
    #expect(parameters.audienceFilterParams["otherParam"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.delegateParams["application_installed_at"] as! String == "abc")
    #expect(parameters.delegateParams["myCustomParam"] as! String == url.absoluteString)
    #expect(parameters.delegateParams["otherParam"] as! Bool)
  }

  @Test func processParameters_superwallEvent_customParams_nilValue() async {
    // Given
    let event = InternalSuperwallEvent.UserAttributes(
      appInstalledAtString: "abc",
      audienceFilterParams: [
        "myCustomParam": nil,
        "otherParam": true,
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "abc"
    )

    #expect(parameters.audienceFilterParams["$is_standard_event"] as! Bool)
    #expect(parameters.audienceFilterParams["$application_installed_at"] as! String == "abc")
    #expect(parameters.audienceFilterParams["$event_name"] as! String == "user_attributes")
    #expect(parameters.audienceFilterParams["myCustomParam"] == nil)
    #expect(parameters.audienceFilterParams["otherParam"] as! Bool)
    #expect(parameters.delegateParams["is_superwall"] as! Bool)
    #expect(parameters.delegateParams["application_installed_at"] as! String == "abc")
    #expect(parameters.delegateParams["myCustomParam"] == nil)
    #expect(parameters.delegateParams["otherParam"] as! Bool)
  }

  // MARK: - didStartNewSession

  @Test @MainActor
  func didStartNewSession_canTriggerPaywall_paywallAlreadyPresented() async {
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    let outcome = await TrackingLogic.canTriggerPaywall(
      InternalSuperwallEvent.AppInstall(
        appInstalledAtString: "", hasExternalPurchaseController: false),
      triggers: Set(["app_install"]),
      paywallViewController: paywallVc
    )
    #expect(outcome == .dontTriggerPaywall)
  }

  @Test func didStartNewSession_canTriggerPaywall_isntTrigger() async {
    let outcome = await TrackingLogic.canTriggerPaywall(
      InternalSuperwallEvent.AppInstall(
        appInstalledAtString: "", hasExternalPurchaseController: false),
      triggers: [],
      paywallViewController: nil
    )
    #expect(outcome == .dontTriggerPaywall)
  }

  @Test func didStartNewSession_canTriggerPaywall_isAllowedInternalEvent() async {
    let outcome = await TrackingLogic.canTriggerPaywall(
      InternalSuperwallEvent.AppInstall(
        appInstalledAtString: "", hasExternalPurchaseController: false),
      triggers: ["app_install"],
      paywallViewController: nil
    )
    #expect(outcome == .triggerPaywall)
  }

  @Test func didStartNewSession_canTriggerPaywall_isNotInternalEvent() async {
    let outcome = await TrackingLogic.canTriggerPaywall(
      UserInitiatedPlacement.Track(
        rawName: "random_event", canImplicitlyTriggerPaywall: true, isFeatureGatable: false),
      triggers: ["random_event"],
      paywallViewController: nil
    )
    #expect(outcome == .triggerPaywall)
  }

  // MARK: - CheckNotSuperwallEvent

  @Test func checkNotSuperwallEvent_isSuperwallEvent() {
    do {
      try TrackingLogic.checkNotSuperwallEvent("paywall_open")
      Issue.record("Should have failed")
    } catch {}
  }

  @Test func checkNotSuperwallEvent_isNotSuperwallEvent() {
    do {
      try TrackingLogic.checkNotSuperwallEvent("my_random_event")
    } catch {
      Issue.record("Should have failed")
    }
  }

  // MARK: - isNotDisabledVerboseEvent

  // This happens when config is null
  @Test func isNotDisabledVerboseEvent_nullVerboseEvents() {
    let event = InternalSuperwallEvent.SessionStart()
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: nil,
      isSandbox: true
    )
    #expect(result)
  }

  @Test func isNotDisabledVerboseEvent_isSandbox_disabledEvents() {
    let event = InternalSuperwallEvent.SessionStart()
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: true,
      isSandbox: true
    )
    #expect(result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_noDisabledEvents_presentationReq() {
    let placement = InternalSuperwallEvent.PresentationRequest(
      placementData: .stub(), type: .presentation, status: .presentation, statusReason: nil,
      factory: DependencyContainer())
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      placement,
      disableVerbosePlacements: false,
      isSandbox: false
    )
    #expect(result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_disabledEvents_presentationReq() {
    let placement = InternalSuperwallEvent.PresentationRequest(
      placementData: .stub(), type: .presentation, status: .presentation, statusReason: nil,
      factory: DependencyContainer())
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      placement,
      disableVerbosePlacements: true,
      isSandbox: false
    )
    #expect(!result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_disabledEvents_paywallLoadStart() {
    let event = InternalSuperwallEvent.PaywallLoad(state: .start, placementData: nil)
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: true,
      isSandbox: false
    )
    #expect(!result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_noDisabledEvents_paywallLoadStart() {
    let event = InternalSuperwallEvent.PaywallLoad(state: .start, placementData: nil)
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: false,
      isSandbox: false
    )
    #expect(result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_disabledEvents_paywallLoadComplete() {
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .complete(paywallInfo: .stub()), placementData: nil)
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: true,
      isSandbox: false
    )
    #expect(!result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_noDisabledEvents_paywallLoadComplete() {
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .complete(paywallInfo: .stub()), placementData: nil)
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: false,
      isSandbox: false
    )
    #expect(result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_disabledEvents_productsLoadStart() {
    let event = InternalSuperwallEvent.PaywallProductsLoad(
      state: .start, paywallInfo: .stub(), placementData: nil)
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: true,
      isSandbox: false
    )
    #expect(!result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_noDisabledEvents_productsLoadStart() {
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .complete(paywallInfo: .stub()), placementData: nil)
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: false,
      isSandbox: false
    )
    #expect(result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_disabledEvents_webviewLoadStart() {
    let event = InternalSuperwallEvent.PaywallWebviewLoad(state: .start, paywallInfo: .stub())
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: true,
      isSandbox: false
    )
    #expect(!result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_noDisabledEvents_webviewLoadStart() {
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .complete(paywallInfo: .stub()), placementData: nil)
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: false,
      isSandbox: false
    )
    #expect(result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_noDisabledEvents_sessionStart() {
    let event = InternalSuperwallEvent.SessionStart()
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: false,
      isSandbox: false
    )
    #expect(result)
  }

  @Test func isNotDisabledVerboseEvent_isNotSandbox_disabledEvents_sessionStart() {
    let event = InternalSuperwallEvent.SessionStart()
    let result = TrackingLogic.isNotDisabledVerbosePlacement(
      event,
      disableVerbosePlacements: true,
      isSandbox: false
    )
    #expect(result)
  }
}
