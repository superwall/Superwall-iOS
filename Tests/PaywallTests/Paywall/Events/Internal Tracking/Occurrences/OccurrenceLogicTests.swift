//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/06/2022.
//

import XCTest
@testable import Paywall

final class OccurrenceLogicTests: XCTestCase {
  func test_getEventOccurrences() {
    let storage = StorageMock(internalTriggeredEvents: ["MyEvent" : [.stub()]])
    let event: EventData = .stub()
      .setting(\.name, to: "MyEvent")

    let occurrences = OccurrenceLogic.getEventOccurrences(
      of: event.name,
      isInPostfix: false,
      storage: storage
    )

    let expectation: [String : Any] = [
      "$count_since_install": 1,
      "$count_30d": 1,
      "$count_7d": 1,
      "$count_24h": 1,
      "$count_session": 1,
      "$count_today": 1,
      "$first_occurred_at": Date(),
      "$last_occurred_at": Date()
    ]
    XCTAssertEqual(occurrences.keys, expectation.keys)
  }
}
