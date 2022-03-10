//
//  PaywallCacheLogicTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

// swiftlint:disable all

import XCTest
@testable import Paywall

class PaywallCacheLogicTests: XCTestCase {
  func testKey_noId_noEvent() {
    // Given + When
    let key = PaywallCacheLogic.key(
      forIdentifier: nil,
      event: nil,
      locale: "en_US"
    )

    // Then
    XCTAssertEqual(key, "$no_id_$no_event_en_US")
  }

  func testKey_noId_withEvent() {
    // Given
    let event = EventData.stub()

    // When
    let key = PaywallCacheLogic.key(
      forIdentifier: nil,
      event: event,
      locale: "en_US"
    )

    // Then
    XCTAssertEqual(key, "$no_id_\(event.name)_en_US")
  }

  func testKey_withId_noEvent() {
    // Given + When
    let key = PaywallCacheLogic.key(
      forIdentifier: "myid",
      event: nil,
      locale: "en_US"
    )

    // Then
    XCTAssertEqual(key, "myid_$no_event_en_US")
  }

  func testKey_withId_withEvent() {
    // Given
    let event = EventData.stub()

    // When
    let key = PaywallCacheLogic.key(
      forIdentifier: "myid",
      event: event,
      locale: "en_US"
    )

    // Then
    XCTAssertEqual(key, "myid_\(event.name)_en_US")
  }
}
