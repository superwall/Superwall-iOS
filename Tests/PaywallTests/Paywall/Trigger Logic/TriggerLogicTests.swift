//
//  TriggerLogicTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

import XCTest
@testable import Paywall

class TriggerLogicTests: XCTestCase {
  func testEventTriggerOutcome_holdout() throws {
    // MARK: Given
    // V2 Trigger
    let eventName = "opened_application"
    let variantId = "7"
    let triggerRule = TriggerRule(
      experiment: Experiment(
        id: "1",
        groupId: "2",
        variant: .init(
          id: variantId,
          type: .holdout,
          paywallId: nil
        )
      ),
      expression: "name == jake",
      expressionJs: nil,
      isAssigned: false
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )

    // EventData
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )

    // Triggers
    let triggers = [eventName: trigger]

    // MARK: When
    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case let .holdout(experiment) = outcome.result else {
      return XCTFail("Incorrect outcome. Expected a holdout")
    }

    XCTAssertEqual(experiment, triggerRule.experiment)

    let expectedConfirmableAssignments = ConfirmableAssignments(
      assignments: [
        Assignment(
          experimentId: triggerRule.experiment.id,
          variantId: variantId
        )
      ]
    )
    let confirmableAssignments = outcome.confirmableAssignments
    XCTAssertEqual(confirmableAssignments, expectedConfirmableAssignments)
  }

  func testEventTriggerOutcome_presentIdentifier() throws {
    // MARK: Given
    // V2 Trigger
    let eventName = "opened_application"
    let variantId = "6"
    let experimentId = "2"
    let experimentGroupId = "1"
    let paywallId = "omnis-id-ab"
    let triggerRule = TriggerRule(
      experiment: Experiment(
        id: experimentId,
        groupId: experimentGroupId,
        variant: .init(
          id: variantId,
          type: .treatment,
          paywallId: paywallId
        )
      ),
      expression: nil,
      expressionJs: nil,
      isAssigned: false
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )

    // EventData
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )

    // Triggers
    let triggers = [eventName: trigger]

    // MARK: When
    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case let .paywall(experiment) = outcome.result else {
      return XCTFail("Incorrect outcome. Expected presentTriggerPaywall")
    }
    XCTAssertEqual(experiment.groupId, experimentGroupId)
    XCTAssertEqual(experiment.variant.paywallId, paywallId)
    XCTAssertEqual(experiment.id, experimentId)
    XCTAssertEqual(experiment.variant.id, variantId)

    let expectedConfirmableAssignments = ConfirmableAssignments(
      assignments: [
        Assignment(
          experimentId: triggerRule.experiment.id,
          variantId: variantId
        )
      ]
    )
    let confirmableAssignments = outcome.confirmableAssignments
    XCTAssertEqual(confirmableAssignments, expectedConfirmableAssignments)
  }

  func testEventTriggerOutcome_noRuleMatch() throws {
    // MARK: Given

    // V2 Trigger
    let eventName = "opened_application"
    let variantId = "6"
    let experimentId = "2"
    let paywallId = "omnis-id-ab"
    let triggerRule = TriggerRule(
      experiment: Experiment(
        id: experimentId,
        groupId: "1",
        variant: .init(
          id: variantId,
          type: .treatment,
          paywallId: paywallId
        )
      ),
      expression: "params.a == c",
      expressionJs: nil,
      isAssigned: false
    )

    let v2Trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )

    // EventData
    let eventData = EventData(
      name: eventName,
      parameters: ["a": "b"],
      createdAt: Date()
    )

    // Triggers
    let triggers = [eventName: v2Trigger]

    // MARK: When

    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case .noRuleMatch = outcome.result else {
      return XCTFail("Incorrect outcome. Expected noRuleMatch")
    }
    let confirmableAssignments = outcome.confirmableAssignments
    XCTAssertNil(confirmableAssignments)
  }

  func testEventTriggerOutcome_unknownEvent() throws {
    // MARK: Given
    // V2 Trigger
    let eventName = "opened_application"
    let variantId = "6"
    let experimentId = "2"
    let experimentGroupId = "1"
    let paywallId = "omnis-id-ab"
    let triggerRule = TriggerRule(
      experiment: Experiment(
        id: experimentId,
        groupId: experimentGroupId,
        variant: .init(
          id: variantId,
          type: .treatment,
          paywallId: paywallId
        )
      ),
      expression: nil,
      expressionJs: nil,
      isAssigned: false
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )

    // EventData
    let eventData = EventData(
      name: "other event",
      parameters: [:],
      createdAt: Date()
    )

    // Triggers
    let triggers = [eventName: trigger]

    // MARK: When
    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case .unknownEvent = outcome.result else {
      return XCTFail("Incorrect outcome. Expected unknown event")
    }

    let confirmableAssignments = outcome.confirmableAssignments
    XCTAssertNil(confirmableAssignments)
  }
}
