//
//  FakeTrackingAuthorizationStatusTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct FakeTrackingAuthorizationStatusTests {
  @Test func rawValues_matchATTrackingManagerAuthorizationStatus() {
    // These should match ATTrackingManager.AuthorizationStatus raw values
    #expect(FakeTrackingAuthorizationStatus.notDetermined.rawValue == 0)
    #expect(FakeTrackingAuthorizationStatus.restricted.rawValue == 1)
    #expect(FakeTrackingAuthorizationStatus.denied.rawValue == 2)
    #expect(FakeTrackingAuthorizationStatus.authorized.rawValue == 3)
  }

  @Test func description_notDetermined() {
    #expect(FakeTrackingAuthorizationStatus.notDetermined.description == "notDetermined")
  }

  @Test func description_restricted() {
    #expect(FakeTrackingAuthorizationStatus.restricted.description == "restricted")
  }

  @Test func description_denied() {
    #expect(FakeTrackingAuthorizationStatus.denied.description == "denied")
  }

  @Test func description_authorized() {
    #expect(FakeTrackingAuthorizationStatus.authorized.description == "authorized")
  }
}
