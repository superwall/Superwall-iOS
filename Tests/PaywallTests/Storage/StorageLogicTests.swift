//
//  StorageLogicTests.swift
//  
//
//  Created by Yusuf Tör on 24/08/2022.
//

import XCTest
@testable import Paywall

final class StorageLogicTests: XCTestCase {
  func test_identify_withSameUserIdAsBefore() {
    let outcome = StorageLogic.identify(
      withUserId: "ab",
      oldUserId: "ab",
      hasRetrievedConfig: true
    )
    XCTAssertEqual(outcome, .checkForStaticConfigUpgrade)
  }

  func test_identify_withDifferentUserIdComparedToBefore() {
    let outcome = StorageLogic.identify(
      withUserId: "ab",
      oldUserId: "cd",
      hasRetrievedConfig: true
    )
    XCTAssertEqual(outcome, .reset)
  }

  func test_identify_fromAnonymous_hasRetrievedConfig() {
    let outcome = StorageLogic.identify(
      withUserId: "ab",
      oldUserId: nil,
      hasRetrievedConfig: true
    )
    XCTAssertEqual(outcome, .loadAssignments)
  }

  func test_identify_fromAnonymous_hasntRetrievedConfig() {
    let outcome = StorageLogic.identify(
      withUserId: "ab",
      oldUserId: nil,
      hasRetrievedConfig: false
    )
    XCTAssertEqual(outcome, .nonBlockingAssignmentDelay)
  }
}
