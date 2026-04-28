//
//  TriggerLogicTests.swift
//
//
//  Created by Yusuf Tör on 09/03/2022.
//
// swiftlint:disable all

import Testing
import Foundation

@testable import SuperwallKit

struct AssignmentLogicTests {
  @Test func getOutcome_holdout() async throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .holdout)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(
        \.variants, to: [variantOption]
      )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      computedPropertyRequests: [],
      preload: .init(behavior: .always)
    )
    let trigger = Trigger(
      placementName: eventName,
      audiences: [triggerRule]
    )
    let eventData = PlacementData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toExperimentVariant()

    let storage = StorageMock()
    storage.overwriteAssignments([Assignment(experimentId: rawExperiment.id, variant: variant, isSentToServer: false)])

    // MARK: When
    let assignmentLogic = AudienceLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )
    let outcome = await assignmentLogic.evaluateAudienceFilters(
      forPlacement: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case let .holdout(returnedExperiment) = outcome.triggerResult else {
      Issue.record("Incorrect outcome. Expected a holdout")
      return
    }
    #expect(returnedExperiment.id == rawExperiment.id)
    #expect(returnedExperiment.groupId == rawExperiment.groupId)
    #expect(returnedExperiment.id == rawExperiment.id)

    let expectedConfirmableAssignments = Assignment(
      experimentId: triggerRule.experiment.id,
      variant: variant,
      isSentToServer: false
    )
    let confirmableAssignments = outcome.assignment!
    #expect(confirmableAssignments == expectedConfirmableAssignments)
  }

  @Test func getOutcome_presentIdentifier_unconfirmedAssignmentsOnly() async throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(
        \.variants, to: [variantOption]
      )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      computedPropertyRequests: [],
      preload: .init(behavior: .always)
    )
    let trigger = Trigger(
      placementName: eventName,
      audiences: [triggerRule]
    )
    let eventData = PlacementData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toExperimentVariant()

    let storage = StorageMock()
    storage.overwriteAssignments([Assignment(experimentId: rawExperiment.id, variant: variant, isSentToServer: false)])

    let assignmentLogic = AudienceLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = await assignmentLogic.evaluateAudienceFilters(
      forPlacement: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.triggerResult else {
      Issue.record("Incorrect outcome. Expected a holdout")
      return
    }
    #expect(returnedExperiment.id == rawExperiment.id)
    #expect(returnedExperiment.groupId == rawExperiment.groupId)
    #expect(returnedExperiment.variant.paywallId == paywallId)
    #expect(returnedExperiment.id == rawExperiment.id)

    let expectedConfirmableAssignments = Assignment(
      experimentId: triggerRule.experiment.id,
      variant: variant,
      isSentToServer: false
    )
    let confirmableAssignments = outcome.assignment!

    #expect(confirmableAssignments == expectedConfirmableAssignments)
  }

  @Test func getOutcome_presentIdentifier_confirmedAssignmentsOnly() async throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(
        \.variants, to: [variantOption]
      )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      computedPropertyRequests: [],
      preload: .init(behavior: .always)
    )
    let trigger = Trigger(
      placementName: eventName,
      audiences: [triggerRule]
    )
    let eventData = PlacementData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toExperimentVariant()

    let storage = StorageMock()
    let assignment = Assignment(experimentId: rawExperiment.id, variant: variant, isSentToServer: true)
    storage.overwriteAssignments([assignment])

    let assignmentLogic = AudienceLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = await assignmentLogic.evaluateAudienceFilters(
      forPlacement: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.triggerResult else {
      Issue.record("Incorrect outcome. Expected a holdout")
      return
    }
    #expect(returnedExperiment.id == rawExperiment.id)
    #expect(returnedExperiment.groupId == rawExperiment.groupId)
    #expect(returnedExperiment.variant.paywallId == paywallId)
    #expect(returnedExperiment.id == rawExperiment.id)

    let outcomeAssignment = outcome.assignment
    #expect(assignment == outcomeAssignment)
  }

  @Test func getOutcome_presentIdentifier_confirmedAssignmentsAndUnconfirmedAssignmentsRaceCondition()
    async throws
  {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(
        \.variants, to: [variantOption]
      )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      computedPropertyRequests: [],
      preload: .init(behavior: .always)
    )
    let trigger = Trigger(
      placementName: eventName,
      audiences: [triggerRule]
    )
    let eventData = PlacementData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toExperimentVariant()
    let variant2 =
      variantOption
      .setting(\.paywallId, to: "123")
      .toExperimentVariant()
    let storage = StorageMock()
    storage.overwriteAssignments([
      Assignment(experimentId: rawExperiment.id, variant: variant, isSentToServer: true),
      Assignment(experimentId: "otherExperimnet", variant: variant2, isSentToServer: false)
    ])

    let assignmentLogic = AudienceLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = await assignmentLogic.evaluateAudienceFilters(
      forPlacement: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case let .paywall(experiment: returnedExperiment) = outcome.triggerResult else {
      Issue.record("Incorrect outcome. Expected a holdout")
      return
    }
    #expect(returnedExperiment.id == rawExperiment.id)
    #expect(returnedExperiment.groupId == rawExperiment.groupId)
    #expect(returnedExperiment.variant.paywallId == paywallId)
    #expect(returnedExperiment.id == rawExperiment.id)

    let assignment = outcome.assignment
    #expect(assignment?.variant == variant)
  }

  @Test func getOutcome_noRuleMatch() async throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(
        \.variants, to: [variantOption]
      )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: "params.a == \"c\"",
      computedPropertyRequests: [],
      preload: .init(behavior: .always)
    )
    let trigger = Trigger(
      placementName: eventName,
      audiences: [triggerRule]
    )
    let eventData = PlacementData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toExperimentVariant()
    let storage = StorageMock()
    storage.overwriteAssignments([Assignment(experimentId: rawExperiment.id, variant: variant, isSentToServer: false)])

    let assignmentLogic = AudienceLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = await assignmentLogic.evaluateAudienceFilters(
      forPlacement: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case .noAudienceMatch = outcome.triggerResult else {
      Issue.record("Incorrect outcome. Expected noAudienceMatch")
      return
    }
    let confirmableAssignments = outcome.assignment
    #expect(confirmableAssignments == nil)
  }

  @Test func getOutcome_triggerNotFound() async throws {
    // MARK: Given
    let eventName = "opened_application"
    let variantId = "7"
    let paywallId = "omnis-id-ab"
    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(
        \.variants, to: [variantOption]
      )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: "params.a == \"c\"",
      computedPropertyRequests: [],
      preload: .init(behavior: .always)
    )
    let trigger = Trigger(
      placementName: eventName,
      audiences: [triggerRule]
    )
    let eventData = PlacementData(
      name: "other event",
      parameters: [:],
      createdAt: Date()
    )
    let triggers = [eventName: trigger]

    let dependencyContainer = DependencyContainer()
    let variant = variantOption.toExperimentVariant()
    let storage = StorageMock()
    storage.overwriteAssignments([Assignment(experimentId: rawExperiment.id, variant: variant, isSentToServer: false)])

    let assignmentLogic = AudienceLogic(
      configManager: dependencyContainer.configManager,
      storage: storage,
      factory: dependencyContainer
    )

    // MARK: When
    let outcome = await assignmentLogic.evaluateAudienceFilters(
      forPlacement: eventData,
      triggers: triggers
    )

    // MARK: Then
    guard case .placementNotFound = outcome.triggerResult else {
      Issue.record("Incorrect outcome. Expected unknown event")
      return
    }

    let confirmableAssignments = outcome.assignment
    #expect(confirmableAssignments == nil)
  }
}
