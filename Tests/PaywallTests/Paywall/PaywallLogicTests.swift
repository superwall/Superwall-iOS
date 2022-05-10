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
      triggers: Set(["app_install"]),
      isPaywallPresented: true
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isntTrigger() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_install",
      triggers: [],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isAllowedInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_install",
      triggers: ["app_install"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isNotInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "random_event",
      triggers: ["random_event"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }

  func testDidStartNewSession_canTriggerPaywall_isInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_open",
      triggers: ["app_open"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .disallowedEventAsTrigger)
  }
}
