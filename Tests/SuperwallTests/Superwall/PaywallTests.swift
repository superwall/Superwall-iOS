//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//

import XCTest
@testable import Superwall

class SuperwallTests: XCTestCase {
  func test_configureCalledTwice() async {
    let superwall = Superwall.configure(apiKey: "abc")
    let superwall2 = Superwall.configure(apiKey: "abc")
    Superwall.shared.configManager = ConfigManagerMock()
    Superwall.shared.identityManager = IdentityManagerMock()

    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)

    XCTAssertEqual(superwall, superwall2)
  }
}
