//
//  Date+IsoStringTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

class Date_IsoStringTests: XCTestCase {
  func testIsoString() {
    // Given
    let date = Date(timeIntervalSince1970: 1646826338.015996)

    // When
    let isoString = date.isoString

    // Then
    let expected = "2022-03-09T11:45:38.016Z"
    XCTAssertEqual(isoString, expected)
  }
}
