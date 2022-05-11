//
//  ConfigResponseLogicTests.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

class ConfigResponseLogicTests: XCTestCase {
  func testGetPaywallIds_trigger_treatments() {
    let paywallId = "abc"
    let rule = TriggerRule.stub()
      .setting(
        \.experiment,
        to: Experiment(
          id: "1",
          groupId: "2",
          variant: .init(
            id: "3",
            type: .treatment,
            paywallId: paywallId
          )
        )
      )

    let trigger = Trigger.stub()
      .setting(\.rules, to: [rule])

    let triggers = Set([trigger])

    let outcome = ConfigResponseLogic.getPaywallIds(fromTriggers: triggers)

    XCTAssertTrue(outcome.contains(paywallId))
  }

  func testGetPaywallIds_trigger_holdouts() {
    let rule = TriggerRule.stub()
      .setting(
        \.experiment,
        to: Experiment(
          id: "1",
          groupId: "2",
          variant: .init(
            id: "3",
            type: .holdout,
            paywallId: nil
          )
        )
      )
    let trigger = Trigger.stub()
      .setting(\.rules, to: [rule])

    let triggers = Set([trigger])

    let outcome = ConfigResponseLogic.getPaywallIds(fromTriggers: triggers)

    XCTAssertTrue(outcome.isEmpty)
  }
}
