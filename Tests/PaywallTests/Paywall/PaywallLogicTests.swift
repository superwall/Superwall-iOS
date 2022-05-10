//
//  PaywallLogicTests.swift
//  
//
//  Created by Yusuf Tör on 10/05/2022.
//

import XCTest
@testable import Paywall

class PaywallLogicTests: XCTestCase {
  func testDidStartNewSession_canTriggerPaywall_paywallAlreadyPresented() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_install",
      v1Triggers: Set(["app_install"]),
      v2Triggers: [],
      isPaywallPresented: true
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isntTrigger() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_install",
      v1Triggers: [],
      v2Triggers: [],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isAllowedInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_install",
      v1Triggers: ["app_install"],
      v2Triggers: [],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isNotInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "random_event",
      v1Triggers: [],
      v2Triggers: ["random_event"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_open",
      v1Triggers: [],
      v2Triggers: ["app_open"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .disallowedEventAsTrigger)
  }
}
