//
//  PaywallLogicTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

// swiftlint:disable all

import XCTest
@testable import Paywall

class PaywallLogicTests: XCTestCase {
  // MARK: - sessionDidStart
  func testSessionDidStart_lastAppCloseNil() {
    let sessionDidStart = PaywallLogic.sessionDidStart(nil)
    XCTAssertTrue(sessionDidStart)
  }

  @available(iOS 13, *)
  func testSessionDidStart_lastAppClosedThirtySecsAgo() {
    let thirtySecondsAgo = Date().advanced(by: -30)
    let sessionDidStart = PaywallLogic.sessionDidStart(thirtySecondsAgo)
    XCTAssertFalse(sessionDidStart)
  }
  
  @available(iOS 13, *)
  func testSessionDidStart_lastAppClosedTwoMinsOneSecAgo() {
    let twoMinsAgo = Date().advanced(by: -121)
    let sessionDidStart = PaywallLogic.sessionDidStart(twoMinsAgo)
    XCTAssertTrue(sessionDidStart)
  }

  // MARK: - canTriggerPaywall
  func testSessionDidStart_canTriggerPaywall_paywallAlreadyPresented() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_install",
      v1Triggers: Set(["app_install"]),
      v2Triggers: [],
      isPaywallPresented: true
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testSessionDidStart_canTriggerPaywall_isntTrigger() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_install",
      v1Triggers: [],
      v2Triggers: [],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .dontTriggerPaywall)
  }

  func testSessionDidStart_canTriggerPaywall_isAllowedInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_install",
      v1Triggers: ["app_install"],
      v2Triggers: [],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }

  func testSessionDidStart_canTriggerPaywall_isNotInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "random_event",
      v1Triggers: [],
      v2Triggers: ["random_event"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .triggerPaywall)
  }

  func testSessionDidStart_canTriggerPaywall_isInternalEvent() {
    let outcome = PaywallLogic.canTriggerPaywall(
      eventName: "app_open",
      v1Triggers: [],
      v2Triggers: ["app_open"],
      isPaywallPresented: false
    )
    XCTAssertEqual(outcome, .disallowedEventAsTrigger)
  }

  // MARK: - trackAppInstall

  func testTrackAppInstall_freshInstall() {
    // Given
    let eventName = Paywall.EventName.appInstall.rawValue
    UserDefaults.standard.removeObject(forKey: eventName)

    let expectation = expectation(description: "Tracking was called")

    let trackEvent: (Trackable) -> TrackingResult = { event in
      XCTAssertEqual(event.rawName, eventName)
      expectation.fulfill()
      return .stub()
    }

    // When
    PaywallLogic.trackAppInstall(
      trackEvent: trackEvent
    )

    // Then
    let appInstall = UserDefaults.standard.bool(forKey: eventName)
    XCTAssertTrue(appInstall)
    waitForExpectations(timeout: 0.1)
  }

  func testTrackAppInstall_alreadyInstalled() {
    // Given
    let eventName = Paywall.EventName.appInstall.rawValue
    UserDefaults.standard.removeObject(forKey: eventName)
    UserDefaults.standard.set(true, forKey: eventName)

    let expectation = expectation(description: "Tracking was called")
    expectation.isInverted = true

    let trackEvent: (Trackable) -> TrackingResult = { event in
      expectation.fulfill()
      return .stub()
    }

    // When
    PaywallLogic.trackAppInstall(
      trackEvent: trackEvent
    )

    // Then
    let appInstall = UserDefaults.standard.bool(forKey: eventName)
    XCTAssertTrue(appInstall)

    waitForExpectations(timeout: 0.1)
  }
}
