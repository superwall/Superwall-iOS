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
  func testKey_noId() {
    // Given + When
    let key = PaywallCacheLogic.key(
      forIdentifier: nil,
      locale: "en_US"
    )

    // Then
    XCTAssertEqual(key, "$no_id_en_US")
  }

  func testKey_withId() {
    // Given + When
    let key = PaywallCacheLogic.key(
      forIdentifier: "myid",
      locale: "en_US"
    )

    // Then
    XCTAssertEqual(key, "myid_en_US")
  }
}
