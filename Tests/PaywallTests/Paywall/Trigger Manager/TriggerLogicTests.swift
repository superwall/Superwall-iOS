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
    let variant = Variant.holdout(
      VariantHoldout(variantId: variantId)
    )
    let triggerRule = TriggerRule(
      experimentId: "2",
      expression: "name == jake",
      isAssigned: false,
      variant: variant,
      variantId: variantId
    )
    let v2Trigger = TriggerV2(
      eventName: eventName,
      rules: [triggerRule]
    )

    // EventData
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: "2022-03-09T11:45:38.016Z"
    )

    // Triggers
    let v1Triggers: Set<String> = []
    let v2Triggers = [eventName: v2Trigger]

    // MARK: When
    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      v1Triggers: v1Triggers,
      v2Triggers: v2Triggers
    )

    // MARK: Then
    guard case let .holdout(
      experimentId: outputExperimentId,
      variantId: outputVariantId
    ) = outcome.result else {
      return XCTFail("Incorrect outcome. Expected a holdout")
    }

    XCTAssertEqual(outputExperimentId, triggerRule.experimentId)
    XCTAssertEqual(outputVariantId, variantId)

    let expectedConfirmableAssignments = ConfirmableAssignments(
      assignments: [
        Assignment(
          experimentId: triggerRule.experimentId,
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
    let paywallId = "omnis-id-ab"
    let variant = Variant.treatment(
      VariantTreatment(
        variantId: variantId,
        paywallIdentifier: paywallId
      )
    )
    let triggerRule = TriggerRule(
      experimentId: experimentId,
      expression: nil,
      isAssigned: false,
      variant: variant,
      variantId: variantId
    )
    let v2Trigger = TriggerV2(
      eventName: eventName,
      rules: [triggerRule]
    )

    // EventData
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: "2022-03-09T11:45:38.016Z"
    )

    // Triggers
    let v1Triggers: Set<String> = []
    let v2Triggers = [eventName: v2Trigger]

    // MARK: When
    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      v1Triggers: v1Triggers,
      v2Triggers: v2Triggers
    )

    // MARK: Then
    guard case let .presentV2(
      experimentId: outputExperimentId,
      variantId: outputVariantId,
      paywallIdentifier: outputPaywallId
    ) = outcome.result else {
      return XCTFail("Incorrect outcome. Expected presentV2")
    }
    XCTAssertEqual(outputPaywallId, paywallId)
    XCTAssertEqual(outputExperimentId, experimentId)
    XCTAssertEqual(outputVariantId, variantId)

    let expectedConfirmableAssignments = ConfirmableAssignments(
      assignments: [
        Assignment(
          experimentId: triggerRule.experimentId,
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
    let variant = Variant.treatment(
      VariantTreatment(
        variantId: variantId,
        paywallIdentifier: paywallId
      )
    )
    let triggerRule = TriggerRule(
      experimentId: experimentId,
      expression: "params.a == c",
      isAssigned: false,
      variant: variant,
      variantId: variantId
    )
    let v2Trigger = TriggerV2(
      eventName: eventName,
      rules: [triggerRule]
    )

    // EventData
    let eventData = EventData(
      name: eventName,
      parameters: ["a": "b"],
      createdAt: "2022-03-09T11:45:38.016Z"
    )

    // Triggers
    let v1Triggers: Set<String> = []
    let v2Triggers = [eventName: v2Trigger]

    // MARK: When

    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      v1Triggers: v1Triggers,
      v2Triggers: v2Triggers
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
    let paywallId = "omnis-id-ab"
    let variant = Variant.treatment(
      VariantTreatment(
        variantId: variantId,
        paywallIdentifier: paywallId
      )
    )
    let triggerRule = TriggerRule(
      experimentId: experimentId,
      expression: nil,
      isAssigned: false,
      variant: variant,
      variantId: variantId
    )
    let v2Trigger = TriggerV2(
      eventName: eventName,
      rules: [triggerRule]
    )

    // EventData
    let eventData = EventData(
      name: "other event",
      parameters: [:],
      createdAt: "2022-03-09T11:45:38.016Z"
    )

    // Triggers
    let v1Triggers: Set<String> = []
    let v2Triggers = [eventName: v2Trigger]

    // MARK: When
    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      v1Triggers: v1Triggers,
      v2Triggers: v2Triggers
    )

    // MARK: Then
    guard case .unknownEvent = outcome.result else {
      return XCTFail("Incorrect outcome. Expected unknown event")
    }

    let confirmableAssignments = outcome.confirmableAssignments
    XCTAssertNil(confirmableAssignments)
  }

  func testEventTriggerOutcome_presentV1() throws {
    // MARK: Given
    let eventName = "open_application"
    let v1Triggers: Set<String> = [eventName]
    let v2Triggers: [String: TriggerV2] = [:]

    // EventData
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: "2022-03-09T11:45:38.016Z"
    )


    // MARK: When
    let outcome = TriggerLogic.outcome(
      forEvent: eventData,
      v1Triggers: v1Triggers,
      v2Triggers: v2Triggers
    )

    // MARK: Then
    guard case .presentV1 = outcome.result else {
      return XCTFail("Incorrect outcome. Expected presentV1")
    }

    let confirmableAssignments = outcome.confirmableAssignments
    XCTAssertNil(confirmableAssignments)
  }
}
