//
//  FakeLocationAuthorizationStatusTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct FakeLocationAuthorizationStatusTests {
  @Test func rawValues_matchCLAuthorizationStatus() {
    // These should match CLAuthorizationStatus raw values
    #expect(FakeLocationAuthorizationStatus.notDetermined.rawValue == 0)
    #expect(FakeLocationAuthorizationStatus.restricted.rawValue == 1)
    #expect(FakeLocationAuthorizationStatus.denied.rawValue == 2)
    #expect(FakeLocationAuthorizationStatus.authorizedAlways.rawValue == 3)
    #expect(FakeLocationAuthorizationStatus.authorizedWhenInUse.rawValue == 4)
  }

  @Test func description_notDetermined() {
    #expect(FakeLocationAuthorizationStatus.notDetermined.description == "notDetermined")
  }

  @Test func description_restricted() {
    #expect(FakeLocationAuthorizationStatus.restricted.description == "restricted")
  }

  @Test func description_denied() {
    #expect(FakeLocationAuthorizationStatus.denied.description == "denied")
  }

  @Test func description_authorizedAlways() {
    #expect(FakeLocationAuthorizationStatus.authorizedAlways.description == "authorizedAlways")
  }

  @Test func description_authorizedWhenInUse() {
    #expect(FakeLocationAuthorizationStatus.authorizedWhenInUse.description == "authorizedWhenInUse")
  }
}
