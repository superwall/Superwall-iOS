//
//  TriggerDelayManagerTests.swift
//  
//
//  Created by Yusuf Tör on 24/08/2022.
//

import XCTest
@testable import Paywall

final class TriggerDelayManagerTests: XCTestCase {
  // MARK: - hasDelay
  func test_hasDelay_configRetrieved_noBlockingAssignmentWaiting() {
    let triggerDelayManager = TriggerDelayManager()
    ConfigManager.shared.config = .stub()

    XCTAssertFalse(triggerDelayManager.hasDelay)
  }

  func test_hasDelay_configNotRetrieved_noBlockingAssignmentWaiting() {
    let triggerDelayManager = TriggerDelayManager()
    ConfigManager.shared.config = nil

    XCTAssertTrue(triggerDelayManager.hasDelay)
  }

  func test_hasDelay_configRetrieved_hasBlockingAssignmentWaiting() {
    let triggerDelayManager = TriggerDelayManager()
    ConfigManager.shared.config = .stub()
    let assignmentCall = PreConfigAssignmentCall(isBlocking: true)
    triggerDelayManager.cachePreConfigAssignmentCall(assignmentCall)

    XCTAssertTrue(triggerDelayManager.hasDelay)
  }

  func test_hasDelay_configNotRetrieved_hasBlockingAssignmentWaiting() {
    let triggerDelayManager = TriggerDelayManager()
    ConfigManager.shared.config = nil
    let assignmentCall = PreConfigAssignmentCall(isBlocking: true)
    triggerDelayManager.cachePreConfigAssignmentCall(assignmentCall)

    XCTAssertTrue(triggerDelayManager.hasDelay)
  }
}
