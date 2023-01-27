//
//  TriggerLogicTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

@available(iOS 14, *)
class AssignmentLogicTests: XCTestCase {
  func testGetOutcome_holdout() throws {
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

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toVariant()
    dependencyContainer.configManager.unconfirmedAssignments = [
      rawExperiment.id: variant
    ]
    let storage = StorageMock()

    // MARK: When
    let assignmentLogic = RuleLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )
    let outcome = assignmentLogic.evaluateRules(
      forEvent: eventData,
      triggers: triggers,
      isPreemptive: false
    )

    // MARK: Then
    guard case let .holdout(returnedExperiment) = outcome.triggerResult else {
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

  func testGetOutcome_presentIdentifier_unconfirmedAssignmentsOnly() throws {
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

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toVariant()
    dependencyContainer.configManager.unconfirmedAssignments = [
      rawExperiment.id: variant
    ]
    let storage = StorageMock()
    let assignmentLogic = RuleLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = assignmentLogic.evaluateRules(
      forEvent: eventData,
      triggers: triggers,
      isPreemptive: false
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.triggerResult else {
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

  func testGetOutcome_presentIdentifier_confirmedAssignmentsOnly() throws {
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

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toVariant()
    let storage = StorageMock(confirmedAssignments: [rawExperiment.id: variant])
    let assignmentLogic = RuleLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = assignmentLogic.evaluateRules(
      forEvent: eventData,
      triggers: triggers,
      isPreemptive: false
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.triggerResult else {
      return XCTFail("Incorrect outcome. Expected a holdout")
    }
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)
    XCTAssertEqual(returnedExperiment.groupId, rawExperiment.groupId)
    XCTAssertEqual(returnedExperiment.variant.paywallId, paywallId)
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)

    let confirmableAssignments = outcome.confirmableAssignment
    XCTAssertNil(confirmableAssignments)
  }

  func testGetOutcome_presentIdentifier_confirmedAssignmentsAndUnconfirmedAssignmentsRaceCondition() throws {
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

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toVariant()
    let variant2 = variantOption
      .setting(\.paywallId, to: "123")
      .toVariant()
    let storage = StorageMock(confirmedAssignments: [rawExperiment.id: variant])
    dependencyContainer.configManager.unconfirmedAssignments = [
      rawExperiment.id: variant2
    ]
    let assignmentLogic = RuleLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = assignmentLogic.evaluateRules(
      forEvent: eventData,
      triggers: triggers,
      isPreemptive: false
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.triggerResult else {
      return XCTFail("Incorrect outcome. Expected a holdout")
    }
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)
    XCTAssertEqual(returnedExperiment.groupId, rawExperiment.groupId)
    XCTAssertEqual(returnedExperiment.variant.paywallId, paywallId)
    XCTAssertEqual(returnedExperiment.id, rawExperiment.id)

    let confirmableAssignments = outcome.confirmableAssignment
    XCTAssertNil(confirmableAssignments)
  }

  func testGetOutcome_noRuleMatch() throws {
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

    let dependencyContainer = DependencyContainer()
    let storage = StorageMock()
    let variant = variantOption.toVariant()
    dependencyContainer.configManager.unconfirmedAssignments = [
      rawExperiment.id: variant
    ]
    let assignmentLogic = RuleLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = assignmentLogic.evaluateRules(
      forEvent: eventData,
      triggers: triggers,
      isPreemptive: false
    )

    // MARK: Then
    guard case .noRuleMatch = outcome.triggerResult else {
      return XCTFail("Incorrect outcome. Expected noRuleMatch")
    }
    let confirmableAssignments = outcome.confirmableAssignment
    XCTAssertNil(confirmableAssignments)
  }

  func testGetOutcome_triggerNotFound() throws {
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

    let dependencyContainer = DependencyContainer()
    let storage = StorageMock()
    let variant = variantOption.toVariant()
    dependencyContainer.configManager.unconfirmedAssignments = [
      rawExperiment.id: variant
    ]
    let assignmentLogic = RuleLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = assignmentLogic.evaluateRules(
      forEvent: eventData,
      triggers: triggers,
      isPreemptive: false
    )

    // MARK: Then
    guard case .eventNotFound = outcome.triggerResult else {
      return XCTFail("Incorrect outcome. Expected unknown event")
    }

    let confirmableAssignments = outcome.confirmableAssignment
    XCTAssertNil(confirmableAssignments)
  }
}
