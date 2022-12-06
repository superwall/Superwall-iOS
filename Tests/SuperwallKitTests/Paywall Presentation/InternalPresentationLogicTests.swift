//
//  InternalPresentationLogicTests.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import XCTest
@testable import SuperwallKit

final class InternalPresentationLogicTests: XCTestCase {
  func test_shouldNotDisplayPaywall_debuggerLaunched() {
    let outcome = InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: true,
      overrides: .init(
        isDebuggerLaunched: true,
        shouldIgnoreSubscriptionStatus: false,
        presentationCondition: .checkUserSubscription
      )
    )
    XCTAssertFalse(outcome)
  }

  func test_shouldNotDisplayPaywall_noPresentationCondition_userIsNotSubscribed() {
    let outcome = InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: false,
      overrides: .init(
        isDebuggerLaunched: false,
        shouldIgnoreSubscriptionStatus: false
      )
    )
    XCTAssertFalse(outcome)
  }

  func test_shouldNotDisplayPaywall_noPresentationCondition_shouldIgnoreSubscriptionStatus() {
    let outcome = InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: true,
      overrides: .init(
        isDebuggerLaunched: false,
        shouldIgnoreSubscriptionStatus: true
      )
    )
    XCTAssertFalse(outcome)
  }

  func test_shouldNotDisplayPaywall_noPresentationCondition_shouldNotIgnoreSubscriptionStatus() {
    let outcome = InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: true,
      overrides: .init(
        isDebuggerLaunched: false,
        shouldIgnoreSubscriptionStatus: false
      )
    )
    XCTAssertTrue(outcome)
  }

  func test_shouldNotDisplayPaywall_presentationCondition_always() {
    let outcome = InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: true,
      overrides: .init(
        isDebuggerLaunched: false,
        shouldIgnoreSubscriptionStatus: false,
        presentationCondition: .always
      )
    )
    XCTAssertFalse(outcome)
  }

  func test_shouldNotDisplayPaywall_presentationCondition_checkSubscription() {
    let outcome = InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: true,
      overrides: .init(
        isDebuggerLaunched: false,
        shouldIgnoreSubscriptionStatus: false,
        presentationCondition: .checkUserSubscription
      )
    )
    XCTAssertTrue(outcome)
  }
}
