//
//  TriggerLogicTests.swift
//  
//
//  Created by Yusuf Tör on 24/08/2022.
//

import XCTest
@testable import Superwall

final class TriggerLogicTests: XCTestCase {
  func test_getTriggerDictionary_() {
    let firstTrigger: Trigger = .stub()
      .setting(\.eventName, to: "abc")

    let secondTrigger: Trigger = .stub()
      .setting(\.eventName, to: "def")

    let triggers: Set<Trigger> = [
      firstTrigger, secondTrigger
    ]
    let dictionary = TriggerLogic.getTriggersByEventName(from: triggers)
    XCTAssertEqual(dictionary["abc"], firstTrigger)
    XCTAssertEqual(dictionary["def"], secondTrigger)
  }
}
