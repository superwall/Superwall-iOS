//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//

import XCTest
@testable import Paywall

class PaywallTests: XCTestCase {
  func test_configureCalledTwice() async {
    let paywall = Paywall.configure(apiKey: "abc")
    let paywall2 = Paywall.configure(apiKey: "abc")
    Paywall.shared.configManager = ConfigManagerMock()
    Paywall.shared.identityManager = IdentityManagerMock()

    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)

    XCTAssertEqual(paywall, paywall2)
  }
}
