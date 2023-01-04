//
//  PaywallLogicTests.swift
//
//
//  Created by Yusuf Tör on 09/03/2022.
//

// swiftlint:disable all

import XCTest
@testable import Paywall

class AppSessionLogicTests: XCTestCase {
  @available(iOS 13, *)
  func testDidStartNewSession_noTimeout() {
    let threeHoursAgo = Date().advanced(by: -10800)
    let sessionDidStart = AppSessionLogic.didStartNewSession(
      threeHoursAgo,
      withSessionTimeout: nil
    )
    XCTAssertTrue(sessionDidStart)
  }

  @available(iOS 13, *)
  func testDidStartNewSession_noTimeout_lastAppClosedFiftyMinsAgo() {
    let fiftyMinsAgo = Date().advanced(by: -3000)
    let sessionDidStart = AppSessionLogic.didStartNewSession(
      fiftyMinsAgo,
      withSessionTimeout: nil
    )
    XCTAssertFalse(sessionDidStart)
  }

  func testDidStartNewSession_freshAppOpen() {
    let timeout = 3600000.0
    let sessionDidStart = AppSessionLogic.didStartNewSession(
      nil,
      withSessionTimeout: timeout
    )
    XCTAssertTrue(sessionDidStart)
  }

  @available(iOS 13, *)
  func testDidStartNewSession_lastAppClosedThirtyMinsAgo() {
    let thirtyMinsAgo = Date().advanced(by: -1800)
    let timeout = 3600000.0
    let sessionDidStart = AppSessionLogic.didStartNewSession(
      thirtyMinsAgo,
      withSessionTimeout: timeout
    )
    XCTAssertFalse(sessionDidStart)
  }

  @available(iOS 13, *)
  func testDidStartNewSession_lastAppClosedThreeHoursAgo() {
    let threeHoursAgo = Date().advanced(by: -10800)
    let timeout = 3600000.0
    let sessionDidStart = AppSessionLogic.didStartNewSession(
      threeHoursAgo,
      withSessionTimeout: timeout
    )
    XCTAssertTrue(sessionDidStart)
  }
}
