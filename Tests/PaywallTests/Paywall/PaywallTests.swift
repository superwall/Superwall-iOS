//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//

import XCTest
@testable import Paywall

class PaywallTests: XCTestCase {
  func test_configureCalledTwice() {
    let paywall = Paywall.configure(apiKey: "abc")
    let paywall2 = Paywall.configure(apiKey: "abc")

    XCTAssertEqual(paywall, paywall2)
  }
}
