//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

class SuperwallTests: XCTestCase {
  func test_configureCalledTwice() async {
    let superwall = Superwall.configure(apiKey: "abc")

    //Superwall.shared.configManager = ConfigManagerMock()
    //Superwall.shared.identityManager = IdentityManagerMock()
    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)
    let superwall2 = Superwall.configure(apiKey: "abc")


    print(superwall, superwall2)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)
    XCTAssertEqual(superwall, superwall2)
  }
}
