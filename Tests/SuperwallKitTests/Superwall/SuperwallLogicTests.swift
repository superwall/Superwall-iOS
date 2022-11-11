//
//  PaywallLogicTests.swift
//  
//
//  Created by Yusuf Tör on 10/05/2022.
//

import XCTest
@testable import SuperwallKit

class SuperwallLogicTests: XCTestCase {
  func testDidStartNewSession_canTriggerPaywall_paywallAlreadyPresented() {
    let outcome = SuperwallLogic.canTriggerPaywall(
      event: InternalSuperwallEvent.AppInstall(),
      triggers: Set(["app_install"]),
      isPaywallPresented: true
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isntTrigger() {
    let outcome = SuperwallLogic.canTriggerPaywall(
      event: InternalSuperwallEvent.AppInstall(),
      triggers: [],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isAllowedInternalEvent() {
    let outcome = SuperwallLogic.canTriggerPaywall(
      event: InternalSuperwallEvent.AppInstall(),
      triggers: ["app_install"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isNotInternalEvent() {
    let outcome = SuperwallLogic.canTriggerPaywall(
      event: UserInitiatedEvent.Track(rawName: "random_event", canImplicitlyTriggerPaywall: true),
      triggers: ["random_event"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }
}
