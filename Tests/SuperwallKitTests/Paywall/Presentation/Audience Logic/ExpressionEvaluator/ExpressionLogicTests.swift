//
//  File.swift
//
//
//  Created by Yusuf Tör on 06/09/2024.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

struct ExpressionLogicTests {
  let dependencyContainer = DependencyContainer()

  @Test func tryToMatchOccurrence_noMatch() async {
    let storage = StorageMock()
    let expressionLogic = ExpressionLogic(storage: storage)

    let rule = TriggerRule.stub()
      .setting(\.occurrence, to: .stub())
    let outcome = await expressionLogic.tryToMatchOccurrence(
      from: rule,
      expressionMatched: false
    )
    #expect(outcome == .noMatch(source: .expression, experimentId: rule.experiment.id))
  }

  @Test func tryToMatchOccurrence_noOccurrenceRule() async {
    let storage = StorageMock()
    let expressionLogic = ExpressionLogic(storage: storage)

    let rule = TriggerRule.stub()
      .setting(\.occurrence, to: nil)
    let outcome = await expressionLogic.tryToMatchOccurrence(
      from: rule,
      expressionMatched: true
    )
    #expect(outcome == .match(audience: rule))
  }

  @Test func tryToMatchOccurrence_shouldntFire_maxCountGTCount() async {
    let coreDataManagerMock = CoreDataManagerFakeDataMock(internalOccurrenceCount: 1)
    let storage = StorageMock(coreDataManager: coreDataManagerMock)
    let expressionLogic = ExpressionLogic(storage: storage)

    let rule = TriggerRule.stub()
      .setting(\.occurrence, to: .stub().setting(\.maxCount, to: 1))
    let outcome = await expressionLogic.tryToMatchOccurrence(
      from: rule,
      expressionMatched: true
    )

    #expect(outcome == .noMatch(source: .occurrence, experimentId: rule.experiment.id))
  }

  @Test func tryToMatchOccurrence_shouldFire_maxCountEqualToCount() async {
    let coreDataManagerMock = CoreDataManagerFakeDataMock(internalOccurrenceCount: 0)
    let storage = StorageMock(coreDataManager: coreDataManagerMock)
    let expressionLogic = ExpressionLogic(storage: storage)

    let occurrence: TriggerAudienceOccurrence = .stub().setting(\.maxCount, to: 1)
    let rule = TriggerRule.stub()
      .setting(\.occurrence, to: occurrence)
    let outcome = await expressionLogic.tryToMatchOccurrence(
      from: rule,
      expressionMatched: true
    )

    #expect(outcome == .match(audience: rule, unsavedOccurrence: occurrence))
  }

  @Test func tryToMatchOccurrence_shouldFire_maxCountLtCount() async {
    let coreDataManagerMock = CoreDataManagerFakeDataMock(internalOccurrenceCount: 1)
    let storage = StorageMock(coreDataManager: coreDataManagerMock)
    let expressionLogic = ExpressionLogic(storage: storage)

    let occurrence: TriggerAudienceOccurrence = .stub().setting(\.maxCount, to: 4)
    let rule = TriggerRule.stub()
      .setting(\.occurrence, to: occurrence)
    let outcome = await expressionLogic.tryToMatchOccurrence(
      from: rule,
      expressionMatched: true
    )

    #expect(outcome == .match(audience: rule, unsavedOccurrence: occurrence))
  }
}
