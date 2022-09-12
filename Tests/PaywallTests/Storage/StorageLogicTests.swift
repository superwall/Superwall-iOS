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
      newUserId: "ab",
      oldUserId: "ab"
    )
    XCTAssertNil(outcome)
  }

  func test_identify_withDifferentUserIdComparedToBefore() {
    let outcome = StorageLogic.identify(
      newUserId: "ab",
      oldUserId: "cd"
    )
    XCTAssertEqual(outcome, .reset)
  }

  func test_identify_fromAnonymous() {
    let outcome = StorageLogic.identify(
      newUserId: "ab",
      oldUserId: nil
    )
    XCTAssertEqual(outcome, .loadAssignments)
  }

  func test_identify_fromAnonymous_noNewUserId_noOldUserId() {
    let outcome = StorageLogic.identify(
      newUserId: nil,
      oldUserId: nil
    )
    XCTAssertNil(outcome)
  }

  func test_identify_fromAnonymous_noNewUser_hasOldUserId() {
    let outcome = StorageLogic.identify(
      newUserId: nil,
      oldUserId: "ab"
    )
    XCTAssertNil(outcome)
  }
}
