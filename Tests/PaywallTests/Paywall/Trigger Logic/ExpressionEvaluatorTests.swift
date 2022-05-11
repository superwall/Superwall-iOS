//
//  File.swift
//  
//
//  Created by Brian Anglin on 2/21/22.
//

import Foundation
import XCTest
@testable import Paywall

final class ExpressionEvaluatorTests: XCTestCase {
  override class func setUp() {
    Storage.shared.clear()
  }


  func testExpressionMatchesAll() {
    let result = ExpressionEvaluator.evaluateExpression(
      expression: nil,
      eventData: .stub()
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluatorTrue() {
    Storage.shared.userAttributes = ["a": "b"]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "user.a == \"b\"",
      eventData: EventData(name: "ss", parameters: [:], createdAt: Date())
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluatorParams() {
    Storage.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "params.a == \"b\"",
      eventData: EventData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluatorDeviceTrue() {
    Storage.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "device.platform == \"iOS\"",
      eventData: EventData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    XCTAssertTrue(result)
  }

  func testExpressionEvaluatorDeviceFalse() {
    Storage.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "device.platform == \"Android\"",
      eventData: EventData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    XCTAssertFalse(result)
  }

  func testExpressionEvaluatorFalse() {
    Storage.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "a == \"b\"",
      eventData: .stub()
    )
    XCTAssertFalse(result)
  }
}
