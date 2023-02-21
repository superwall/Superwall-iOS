//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/09/2022.
//

import XCTest
@testable import SuperwallKit

final class IdentityLogicTests: XCTestCase {
  func test_shouldGetAssignments_hasAccount_accountExistedPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: true,
      neverCalledStaticConfig: true,
      isFirstAppOpen: true
    )
    XCTAssertTrue(outcome)
  }

  func test_shouldGetAssignments_isAnonymous_firstAppOpen_accountExistedPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: false,
      neverCalledStaticConfig: true,
      isFirstAppOpen: true
    )
    XCTAssertFalse(outcome)
  }

  func test_shouldGetAssignments_hasAccount_noAccountPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: true,
      neverCalledStaticConfig: false,
      isFirstAppOpen: true
    )
    XCTAssertFalse(outcome)
  }

  func test_shouldGetAssignments_isAnonymous_isFirstAppOpen() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: false,
      neverCalledStaticConfig: false,
      isFirstAppOpen: true
    )
    XCTAssertFalse(outcome)
  }

  func test_shouldGetAssignments_isAnonymous_isNotFirstAppOpen_accountExistedPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: false,
      neverCalledStaticConfig: true,
      isFirstAppOpen: false
    )
    XCTAssertTrue(outcome)
  }

  func test_shouldGetAssignments_isAnonymous_isNotFirstAppOpen_noAccountPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: false,
      neverCalledStaticConfig: false,
      isFirstAppOpen: false
    )
    XCTAssertFalse(outcome)
  }
}
