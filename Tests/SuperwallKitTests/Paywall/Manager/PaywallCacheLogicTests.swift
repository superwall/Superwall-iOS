//
//  PaywallCacheLogicTests.swift
//
//
//  Created by Yusuf Tör on 09/03/2022.
//

// swiftlint:disable all

import Testing
@testable import SuperwallKit

struct PaywallCacheLogicTests {
  @Test func key_withId() {
    // Given + When
    let key = PaywallCacheLogic.key(
      identifier: "myid",
      locale: "en_US"
    )

    // Then
    #expect(key == "myid_en_US")
  }
}
