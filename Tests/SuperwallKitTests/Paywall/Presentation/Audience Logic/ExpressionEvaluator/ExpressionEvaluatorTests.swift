//
//  File.swift
//  
//
//  Created by Brian Anglin on 2/21/22.
//
// swiftlint:disable all

import Foundation
import XCTest
@testable import SuperwallKit

@available(iOS 14.0, *)
final class ExpressionEvaluatorTests: XCTestCase {
  // MARK: - evaluateExpression
  func testExpressionMatchesAll() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )

    let rule: TriggerRule = .stub()
      .setting(\.expression, to: nil)
      .setting(\.expressionJs, to: nil)
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )

    XCTAssertEqual(result, .match(audience: rule))
  }

  // MARK: - Expression

  func testExpressionEvaluator_expressionTrue() async  {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes(["a": "b"])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "user.a == \"b\"")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: [:], createdAt: Date())
    )

    XCTAssertEqual(result, .match(audience: rule))
  }

  func testExpressionEvaluator_expression_withOccurrence() async  {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes(["a": "b"])
    let occurrence = TriggerAudienceOccurrence(key: "a", maxCount: 1, interval: .infinity)
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "user.a == \"b\"")
      .setting(\.occurrence, to: occurrence)
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: [:], createdAt: Date())
    )

    XCTAssertEqual(result, .match(audience: rule, unsavedOccurrence: occurrence))
  }

  func testExpressionEvaluator_expressionParams() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "params.a == \"b\"")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    XCTAssertEqual(result, .match(audience: rule))
  }

  func testExpressionEvaluator_expressionDeviceTrue() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "device.platform == \"iOS\"")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    XCTAssertEqual(result, .match(audience: rule))
  }

  func testExpressionEvaluator_expressionDeviceFalse() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "device.platform == \"Android\"")
    let result = await evaluator.evaluateExpression(
        fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    XCTAssertEqual(result, .noMatch(source: .expression, experimentId: rule.experiment.id))
  }

  func testExpressionEvaluator_expressionFalse() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "a == \"b\"")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    XCTAssertEqual(result, .noMatch(source: .expression, experimentId: rule.experiment.id))
  }
/*
  func testExpressionEvaluator_events() {
    let triggeredEvents: [String: [PlacementData]] = [
      "a": [.stub()]
    ]
    let storage = StorageMock(internalTriggeredEvents: triggeredEvents)
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expression, to: "events[\"a\"][\"$count_24h\"] == 1"),
      eventData: .stub(),
      storage: storage
    )
    XCTAssertTrue(result)
  }*/

  // MARK: - ExpressionJS

  func testExpressionEvaluator_expressionJSTrue() async {
    let dependencyContainer = DependencyContainer()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    let rule: TriggerRule = .stub()
      .setting(\.expressionJs, to: "function superwallEvaluator(){ return true }; superwallEvaluator")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    XCTAssertEqual(result, .match(audience: rule))
  }

  func testExpressionEvaluator_expressionJSValues_true() async {
      let dependencyContainer = DependencyContainer()
      let evaluator = ExpressionEvaluator(
        storage: dependencyContainer.storage,
        factory: dependencyContainer
      )
    let rule: TriggerRule = .stub()
      .setting(\.expressionJs, to: "function superwallEvaluator(values) { return values.params.a ==\"b\" }; superwallEvaluator")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    XCTAssertEqual(result, .match(audience: rule))
  }

  func testExpressionEvaluator_expressionJSValues_false() async {
    let dependencyContainer = DependencyContainer()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    let rule: TriggerRule = .stub()
      .setting(\.expressionJs, to: "function superwallEvaluator(values) { return values.params.a ==\"b\" }; superwallEvaluator")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    XCTAssertEqual(result, .match(audience: rule))
  }

  func testExpressionEvaluator_expressionJSNumbers() async {
    let dependencyContainer = DependencyContainer()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    let rule: TriggerRule = .stub()
      .setting(\.expressionJs, to: "function superwallEvaluator(values) { return 1 == 1 }; superwallEvaluator")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    XCTAssertEqual(result, .match(audience: rule))
  }
/*
  func testExpressionEvaluator_expressionJSValues_events() {
    let triggeredEvents: [String: [PlacementData]] = [
      "a": [.stub()]
    ]
    let storage = StorageMock(internalTriggeredEvents: triggeredEvents)
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expressionJs, to: "function superwallEvaluator(values) { return values.events.a.$count_24h == 1 }; superwallEvaluator"),
      eventData: .stub(),
      storage: storage
    )
    XCTAssertTrue(result)
  }*/

  func testExpressionEvaluator_expressionJSEmpty() async {
    let dependencyContainer = DependencyContainer()
    let evaluator = ExpressionEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    let rule: TriggerRule = .stub()
      .setting(\.expressionJs, to: "")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    XCTAssertEqual(result, .noMatch(source: .expression, experimentId: rule.experiment.id))
  }
}
