//
//  File.swift
//
//
//  Created by Yusuf Tör on 29/09/2022.
//

import Testing
@testable import SuperwallKit

struct IdentityLogicTests {
  @Test func shouldGetAssignments_hasAccount_accountExistedPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: true,
      neverCalledStaticConfig: true,
      isFirstAppOpen: true
    )
    #expect(outcome)
  }

  @Test func shouldGetAssignments_isAnonymous_firstAppOpen_accountExistedPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: false,
      neverCalledStaticConfig: true,
      isFirstAppOpen: true
    )
    #expect(!outcome)
  }

  @Test func shouldGetAssignments_hasAccount_noAccountPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: true,
      neverCalledStaticConfig: false,
      isFirstAppOpen: true
    )
    #expect(!outcome)
  }

  @Test func shouldGetAssignments_isAnonymous_isFirstAppOpen() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: false,
      neverCalledStaticConfig: false,
      isFirstAppOpen: true
    )
    #expect(!outcome)
  }

  @Test func shouldGetAssignments_isAnonymous_isNotFirstAppOpen_accountExistedPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: false,
      neverCalledStaticConfig: true,
      isFirstAppOpen: false
    )
    #expect(outcome)
  }

  @Test func shouldGetAssignments_isAnonymous_isNotFirstAppOpen_noAccountPreStaticConfig() {
    let outcome = IdentityLogic.shouldGetAssignments(
      isLoggedIn: false,
      neverCalledStaticConfig: false,
      isFirstAppOpen: false
    )
    #expect(!outcome)
  }
}
