//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

final class URLSessionRetryLogicTests: XCTestCase {
  func test_delay_lastAttempt() {
    let delay = TaskRetryLogic.delay(
      forAttempt: 6,
      maxRetries: 6
    )!
    let twentySixSeconds = UInt64(26_000_000_000)

    XCTAssertLessThanOrEqual(UInt64(delay/1000), twentySixSeconds)
  }
  
  func test_delay_tooManyAttempts() {
    let delay = TaskRetryLogic.delay(
      forAttempt: 7,
      maxRetries: 6
    )
    XCTAssertNil(delay)
  }
}
