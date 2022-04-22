//
//  InternalEventLogicTests.swift
//  
//
//  Created by Yusuf Tör on 22/04/2022.
//

import XCTest
@testable import Paywall

final class InternalEventLogicTests: XCTestCase {
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
      canTriggerPaywall: false
    )

    // When
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    XCTAssertFalse(parameters.eventParams["$is_standard_event"] as! Bool)
    XCTAssertTrue(parameters.delegateParams["isSuperwall"] as! Bool)
  }
}
