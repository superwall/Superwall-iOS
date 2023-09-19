//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/09/2023.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

class Date_WithinAnHourBeforeTests: XCTestCase {
  func test_isWithinAnHourBefore_twoHoursAgo() {
    let now = Date()
    let oneHourBefore = now.addingTimeInterval(-7200)
    let result = oneHourBefore.isWithinAnHourBefore(now)
    XCTAssertFalse(result)
  }

  func test_isWithinAnHourBefore_oneHourAgo() {
    let now = Date()
    let oneHourBefore = now.addingTimeInterval(-3600)
    let result = oneHourBefore.isWithinAnHourBefore(now)
    XCTAssertFalse(result)
  }

  func test_isWithinAnHourBefore_59minsAgo() {
    let now = Date()
    let oneHourBefore = now.addingTimeInterval(-3599)
    let result = oneHourBefore.isWithinAnHourBefore(now)
    XCTAssertTrue(result)
  }

  func test_isWithinAnHourBefore_exactSame() {
    let now = Date()
    let oneHourBefore = now
    let result = oneHourBefore.isWithinAnHourBefore(now)
    XCTAssertTrue(result)
  }

  func test_isWithinAnHourBefore_inFuture() {
    let now = Date()
    let oneHourBefore = now.addingTimeInterval(60)
    let result = oneHourBefore.isWithinAnHourBefore(now)
    XCTAssertTrue(result)
  }
}
