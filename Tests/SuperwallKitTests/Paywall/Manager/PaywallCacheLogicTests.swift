//
//  PaywallCacheLogicTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

// swiftlint:disable all

import XCTest
@testable import SuperwallKit

class PaywallCacheLogicTests: XCTestCase {
  func testKey_withId() {
    // Given + When
    let key = PaywallCacheLogic.key(
      identifier: "myid",
      locale: "en_US"
    )

    // Then
    XCTAssertEqual(key, "myid_en_US")
  }
}
