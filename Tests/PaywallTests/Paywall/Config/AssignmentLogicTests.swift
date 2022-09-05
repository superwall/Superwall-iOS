//
//  TriggerLogicTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

@available(iOS 14, *)
class AssignmentLogicTests: XCTestCase {
  func testEventTriggerOutcome_holdout() throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .holdout)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let configManager = ConfigManager()
    let variant = variantOption.toVariant()
    configManager.unconfirmedAssignments = [
      rawExperiment.id: variant
    ]
    let storage = StorageMock()

    // MARK: When
    let outcome = AssignmentLogic.getOutcome(
      forEvent: eventData,
      triggers: triggers,
      configManager: configManager,
      storage: storage
    )

    // MARK: Then
    guard case let .holdout(returnedExperiment) = outcome.result else {
      return XCTFail("Incorrect outcome. Expected a holdout")
    }
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)
    XCTAssertEqual(returnedExperiment.groupId, rawExperiment.groupId)
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)

    let expectedConfirmableAssignments = ConfirmableAssignment(
      experimentId: triggerRule.experiment.id,
      variant: variant
    )
    let confirmableAssignments = outcome.confirmableAssignment!
    XCTAssertEqual(confirmableAssignments, expectedConfirmableAssignments)
  }

  func testEventTriggerOutcome_presentIdentifier_unconfirmedAssignmentsOnly() throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let configManager = ConfigManager()
    let variant = variantOption.toVariant()
    configManager.unconfirmedAssignments = [
      rawExperiment.id: variant
    ]
    let storage = StorageMock()

    // MARK: When
    let outcome = AssignmentLogic.getOutcome(
      forEvent: eventData,
      triggers: triggers,
      configManager: configManager,
      storage: storage
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.result else {
      return XCTFail("Incorrect outcome. Expected a holdout")
    }
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)
    XCTAssertEqual(returnedExperiment.groupId, rawExperiment.groupId)
    XCTAssertEqual(returnedExperiment.variant.paywallId, paywallId)
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)

    let expectedConfirmableAssignments = ConfirmableAssignment(
      experimentId: triggerRule.experiment.id,
      variant: variant
    )
    let confirmableAssignments = outcome.confirmableAssignment!
    XCTAssertEqual(confirmableAssignments, expectedConfirmableAssignments)
  }

  func testEventTriggerOutcome_presentIdentifier_confirmedAssignmentsOnly() throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let configManager = ConfigManager()
    let variant = variantOption.toVariant()
    let storage = StorageMock(confirmedAssignments: [rawExperiment.id: variant])

    // MARK: When
    let outcome = AssignmentLogic.getOutcome(
      forEvent: eventData,
      triggers: triggers,
      configManager: configManager,
      storage: storage
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.result else {
      return XCTFail("Incorrect outcome. Expected a holdout")
    }
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)
    XCTAssertEqual(returnedExperiment.groupId, rawExperiment.groupId)
    XCTAssertEqual(returnedExperiment.variant.paywallId, paywallId)
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)

    let confirmableAssignments = outcome.confirmableAssignment
    XCTAssertNil(confirmableAssignments)
  }

  func testEventTriggerOutcome_presentIdentifier_confirmedAssignmentsAndUnconfirmedAssignmentsRaceCondition() throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let configManager = ConfigManager()
    let variant = variantOption.toVariant()
    let variant2 = variantOption
      .setting(\.paywallId, to: "123")
      .toVariant()
    let storage = StorageMock(confirmedAssignments: [rawExperiment.id: variant])
    configManager.unconfirmedAssignments = [
      rawExperiment.id: variant2
    ]

    // MARK: When
    let outcome = AssignmentLogic.getOutcome(
      forEvent: eventData,
      triggers: triggers,
      configManager: configManager,
      storage: storage
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.result else {
      return XCTFail("Incorrect outcome. Expected a holdout")
    }
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)
    XCTAssertEqual(returnedExperiment.groupId, rawExperiment.groupId)
    XCTAssertEqual(returnedExperiment.variant.paywallId, paywallId)
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)

    let confirmableAssignments = outcome.confirmableAssignment
    XCTAssertNil(confirmableAssignments)
  }

  func testEventTriggerOutcome_noRuleMatch() throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: "params.a == \"c\"",
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let storage = StorageMock()
    let configManager = ConfigManager()
    let variant = variantOption.toVariant()
    configManager.unconfirmedAssignments = [
      rawExperiment.id: variant
    ]

    // MARK: When
    let outcome = AssignmentLogic.getOutcome(
      forEvent: eventData,
      triggers: triggers,
      configManager: configManager,
      storage: storage
    )

    // MARK: Then
    guard case .noRuleMatch = outcome.result else {
      return XCTFail("Incorrect outcome. Expected noRuleMatch")
    }
    let confirmableAssignments = outcome.confirmableAssignment
    XCTAssertNil(confirmableAssignments)
  }

  func testEventTriggerOutcome_unknownEvent() throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: "params.a == \"c\"",
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )
    let eventData = EventData(
      name: "other event",
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let storage = StorageMock()
    let configManager = ConfigManager()
    let variant = variantOption.toVariant()
    configManager.unconfirmedAssignments = [
      rawExperiment.id: variant
    ]

    // MARK: When
    let outcome = AssignmentLogic.getOutcome(
      forEvent: eventData,
      triggers: triggers,
      configManager: configManager,
      storage: storage
    )

    // MARK: Then
    guard case .unknownEvent = outcome.result else {
      return XCTFail("Incorrect outcome. Expected unknown event")
    }

    let confirmableAssignments = outcome.confirmableAssignment
    XCTAssertNil(confirmableAssignments)
  }
}
