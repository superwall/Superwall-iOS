//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

final class URLSessionRetryLogicTests: XCTestCase {
  func test_delay_lastAttempt() {
    let delay = URLSessionRetryLogic.delay(forAttempt: 6)!
    XCTAssertEqual(Int(delay/1000), 25)
  }
  
  func test_delay_tooManyAttempts() {
    let delay = URLSessionRetryLogic.delay(forAttempt: 7)
    XCTAssertNil(delay)
  }
}
