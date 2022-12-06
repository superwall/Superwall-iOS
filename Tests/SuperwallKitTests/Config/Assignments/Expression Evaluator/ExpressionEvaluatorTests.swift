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

final class ExpressionEvaluatorTests: XCTestCase {
  override class func setUp() {
    Storage.shared.reset()
  }

  func testExpressionMatchesAll() {
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expression, to: nil)
        .setting(\.expressionJs, to: nil),
      eventData: .stub(),
      isPreemptive: false
    )
    XCTAssertTrue(result)
  }

  // MARK: - Expression

  func testExpressionEvaluator_expressionTrue() {
    IdentityManager.shared.userAttributes = ["a": "b"]
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expression, to: "user.a == \"b\""),
      eventData: EventData(name: "ss", parameters: [:], createdAt: Date()),
      isPreemptive: false
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluator_expressionParams() {
    IdentityManager.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expression, to: "params.a == \"b\""),
      eventData: EventData(name: "ss", parameters: ["a": "b"], createdAt: Date()),
      isPreemptive: false
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluator_expressionDeviceTrue() {
    IdentityManager.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expression, to: "device.platform == \"iOS\""),
      eventData: EventData(name: "ss", parameters: ["a": "b"], createdAt: Date()),
      isPreemptive: false
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluator_expressionDeviceFalse() {
    IdentityManager.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
        fromRule: .stub()
          .setting(\.expression, to: "device.platform == \"Android\""),
      eventData: EventData(name: "ss", parameters: ["a": "b"], createdAt: Date()),
        isPreemptive: false
    )
    XCTAssertFalse(result)
  }

  func testExpressionEvaluator_expressionFalse() {
    IdentityManager.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expression, to: "a == \"b\""),
      eventData: .stub(),
      isPreemptive: false
    )
    XCTAssertFalse(result)
  }
/*
  func testExpressionEvaluator_events() {
    let triggeredEvents: [String: [EventData]] = [
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

  func testExpressionEvaluator_expressionJSTrue() {
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expressionJs, to: "function superwallEvaluator(){ return true }; superwallEvaluator"),
      eventData: .stub(),
      isPreemptive: false
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluator_expressionJSValues_true() {
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expressionJs, to: "function superwallEvaluator(values) { return values.params.a ==\"b\" }; superwallEvaluator"),
      eventData: EventData(name: "ss", parameters: ["a": "b"], createdAt: Date()),
      isPreemptive: false
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluator_expressionJSValues_false() {
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expressionJs, to: "function superwallEvaluator(values) { return values.params.a ==\"b\" }; superwallEvaluator"),
      eventData: EventData(name: "ss", parameters: ["a": "b"], createdAt: Date()),
      isPreemptive: false
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluator_expressionJSNumbers() {
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expressionJs, to: "function superwallEvaluator(values) { return 1 == 1 }; superwallEvaluator"),
      eventData: .stub(),
      isPreemptive: false
    )
    XCTAssertTrue(result)
  }
/*
  func testExpressionEvaluator_expressionJSValues_events() {
    let triggeredEvents: [String: [EventData]] = [
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

  func testExpressionEvaluator_expressionJSEmpty() {
    let result = ExpressionEvaluator.evaluateExpression(
      fromRule: .stub()
        .setting(\.expressionJs, to: ""),
      eventData: .stub(),
      isPreemptive: false
    )
    XCTAssertFalse(result)
  }
}
