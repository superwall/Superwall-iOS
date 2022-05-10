//
//  InternalEventLogicTests.swift
//  
//
//  Created by Yusuf Tör on 22/04/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

final class TrackingLogicTests: XCTestCase {
  func testProcessParameters_superwallEvent_noParams() {
    // Given
    let event = SuperwallEvent.AppLaunch()

    // When
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
  }

  func testProcessParameters_userEvent_noParams() {
    // Given
    let event = UserInitiatedEvent.Track(
      rawName: "test",
      canImplicitlyTriggerPaywall: false
    )

    // When
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertFalse(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
  }

  func testProcessParameters_superwallEvent_noCustomParams() {
    // Given
    let eventName = "TestName"
    let event = SuperwallEvent.PaywallResponseLoad(
      state: .start,
      eventData: EventData
        .stub()
        .setting(\.name, to: eventName)
    )
    // When
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$eventName"] as! String, "TestName")
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["eventName"] as! String, "TestName")
  }

  func testProcessParameters_superwallEvent_withCustomParams() {
    // Given
    let eventName = "TestName"
    let event = SuperwallEvent.PaywallResponseLoad(
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
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$eventName"] as! String, "TestName")
    XCTAssertEqual(parameters.eventParams["myCustomParam"] as! String, "hello")
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["eventName"] as! String, "TestName")
    XCTAssertEqual(parameters.delegateParams["myCustomParam"] as! String, "hello")
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containsDollar() {
    // Given
    let eventName = "TestName"
    let event = SuperwallEvent.PaywallResponseLoad(
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
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$eventName"] as! String, "TestName")
    XCTAssertNil(parameters.eventParams["$myCustomParam"])
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["eventName"] as! String, "TestName")
    XCTAssertNil(parameters.delegateParams["$myCustomParam"])
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containArray() {
    // Given
    let eventName = "TestName"
    let event = SuperwallEvent.PaywallResponseLoad(
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
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$eventName"] as! String, "TestName")
    XCTAssertNil(parameters.eventParams["myCustomParam"])
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["eventName"] as! String, "TestName")
    XCTAssertNil(parameters.delegateParams["myCustomParam"])
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containDictionary() {
    // Given
    let eventName = "TestName"
    let event = SuperwallEvent.PaywallResponseLoad(
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
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$eventName"] as! String, "TestName")
    XCTAssertNil(parameters.eventParams["myCustomParam"])
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["eventName"] as! String, "TestName")
    XCTAssertNil(parameters.delegateParams["myCustomParam"])
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containsDate() {
    // Given
    let date = Date(timeIntervalSince1970: 1650534735)
    let eventName = "TestName"
    let event = SuperwallEvent.PaywallResponseLoad(
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
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$eventName"] as! String, "TestName")
    XCTAssertEqual(parameters.eventParams["myCustomParam"] as! String, date.isoString)
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["eventName"] as! String, "TestName")
    XCTAssertEqual(parameters.delegateParams["myCustomParam"] as! String, date.isoString)
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_containsUrl() {
    // Given
    let url = URL(string: "https://www.google.com")!
    let eventName = "TestName"
    let event = SuperwallEvent.PaywallResponseLoad(
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
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$eventName"] as! String, "TestName")
    XCTAssertEqual(parameters.eventParams["myCustomParam"] as! String, url.absoluteString)
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["eventName"] as! String, "TestName")
    XCTAssertEqual(parameters.delegateParams["myCustomParam"] as! String, url.absoluteString)
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }

  func testProcessParameters_superwallEvent_customParams_nilValue() {
    // Given
    let eventName = "TestName"
    let event = SuperwallEvent.PaywallResponseLoad(
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
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertTrue(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.eventParams["$isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.eventParams["$eventName"] as! String, "TestName")
    XCTAssertNil(parameters.eventParams["myCustomParam"])
    XCTAssertTrue(parameters.eventParams["otherParam"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isTriggeredFromEvent"] as! Bool)
    XCTAssertEqual(parameters.delegateParams["eventName"] as! String, "TestName")
    XCTAssertNil(parameters.delegateParams["myCustomParam"])
    XCTAssertTrue(parameters.delegateParams["otherParam"] as! Bool)
  }
}
