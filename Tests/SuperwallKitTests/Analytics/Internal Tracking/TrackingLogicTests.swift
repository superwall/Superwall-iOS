//
//  InternalEventLogicTests.swift
//  
//
//  Created by Yusuf Tör on 22/04/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

@available(iOS 14.0, *)
final class TrackingLogicTests: XCTestCase {
  func testProcessParameters_superwallEvent_noParams() async {
    // Given
    let event = InternalSuperwallEvent.AppLaunch()
    let storage = StorageMock()

    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: Date(),
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
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

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$count_24h"] as! Int, 2)
  }*/

  func testProcessParameters_userEvent_noParams() async {
    // Given
    let event = UserInitiatedEvent.Track(
      rawName: "test",
      canImplicitlyTriggerPaywall: false
    )
    let storage = StorageMock()

    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: Date(),
      appSessionId: "abc"
    )

    XCTAssertFalse(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
  }
/*
  func testProcessParameters_userEvent_noParams_firedTwice() {
    // Given
    let event = UserInitiatedEvent.Track(
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

    XCTAssertFalse(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$count_24h"] as! Int, 2)
  }
*/
  func testProcessParameters_superwallEvent_noCustomParams() async {
    // Given
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName)
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: event.eventData!.createdAt,
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$event_name"] as! String, "TestName")
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["event_name"] as! String, "TestName")
  }

  func testProcessParameters_superwallEvent_withCustomParams() async {
    // Given
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName),
      customParameters: [
        "myCustomParam": "hello",
        "otherParam": true
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: event.eventData!.createdAt,
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$event_name"] as! String, "TestName")
    XCTAssertEqual(parameters.eventParams["myCustomParam"] as! String, "hello")
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["event_name"] as! String, "TestName")
    XCTAssertEqual(parameters.delegateParams["myCustomParam"] as! String, "hello")
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containsDollar() async {
    // Given
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName),
      customParameters: [
        "$myCustomParam": "hello",
        "otherParam": true
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: event.eventData!.createdAt,
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$event_name"] as! String, "TestName")
    XCTAssertNil(parameters.eventParams["$myCustomParam"])
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["event_name"] as! String, "TestName")
    XCTAssertNil(parameters.delegateParams["$myCustomParam"])
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containArray() async {
    // Given
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName),
      customParameters: [
        "myCustomParam": ["hello"],
        "otherParam": true
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: event.eventData!.createdAt,
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$event_name"] as! String, "TestName")
    XCTAssertNil(parameters.eventParams["myCustomParam"])
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["event_name"] as! String, "TestName")
    XCTAssertNil(parameters.delegateParams["myCustomParam"])
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containDictionary() async {
    // Given
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName),
      customParameters: [
        "myCustomParam": ["one" : "hello"],
        "otherParam": true
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: event.eventData!.createdAt,
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$event_name"] as! String, "TestName")
    XCTAssertNil(parameters.eventParams["myCustomParam"])
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["event_name"] as! String, "TestName")
    XCTAssertNil(parameters.delegateParams["myCustomParam"])
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containsDate() async {
    // Given
    let date = Date(timeIntervalSince1970: 1650534735)
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName),
      customParameters: [
        "myCustomParam": date,
        "otherParam": true
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: event.eventData!.createdAt,
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$event_name"] as! String, "TestName")
    XCTAssertEqual(parameters.eventParams["myCustomParam"] as! String, date.isoString)
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["event_name"] as! String, "TestName")
    XCTAssertEqual(parameters.delegateParams["myCustomParam"] as! String, date.isoString)
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containsUrl() async {
    // Given
    let url = URL(string: "https://www.google.com")!
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName),
      customParameters: [
        "myCustomParam": url,
        "otherParam": true
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: event.eventData!.createdAt,
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$event_name"] as! String, "TestName")
    XCTAssertEqual(parameters.eventParams["myCustomParam"] as! String, url.absoluteString)
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["event_name"] as! String, "TestName")
    XCTAssertEqual(parameters.delegateParams["myCustomParam"] as! String, url.absoluteString)
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_nilValue() async {
    // Given
    let eventName = "TestName"
    let event = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName),
      customParameters: [
        "myCustomParam": nil,
        "otherParam": true
      ]
    )
    // When
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: event.eventData!.createdAt,
      appSessionId: "abc"
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$event_name"] as! String, "TestName")
    XCTAssertNil(parameters.eventParams["myCustomParam"])
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_superwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["is_triggered_from_event"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["event_name"] as! String, "TestName")
    XCTAssertNil(parameters.delegateParams["myCustomParam"])
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  // MARK: - didStartNewSession

  func testDidStartNewSession_canTriggerPaywall_paywallAlreadyPresented() {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let outcome = TrackingLogic.canTriggerPaywall(
      InternalSuperwallEvent.AppInstall(deviceHelper: dependencyContainer.deviceHelper),
      triggers: Set(["app_install"]),
      isPaywallPresented: true
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isntTrigger() {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let outcome = TrackingLogic.canTriggerPaywall(
      InternalSuperwallEvent.AppInstall(deviceHelper: dependencyContainer.deviceHelper),
      triggers: [],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isAllowedInternalEvent() {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let outcome = TrackingLogic.canTriggerPaywall(
      InternalSuperwallEvent.AppInstall(deviceHelper: dependencyContainer.deviceHelper),
      triggers: ["app_install"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isNotInternalEvent() {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let outcome = TrackingLogic.canTriggerPaywall(
      UserInitiatedEvent.Track(rawName: "random_event", canImplicitlyTriggerPaywall: true),
      triggers: ["random_event"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }
}
