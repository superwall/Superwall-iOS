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

  // TODO: Why is this failing?

  func testExpressionMatchesAll() {
    let result = ExpressionEvaluator.evaluateExpression(
      expression: nil,
      eventData: .stub()
    )
    XCTAssertTrue(result)
  }

  /*func testExpressionEvaluatorTrue() {
    Storage.shared.userAttributes = ["a": "b"]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "a == \"b\"",
      eventData: EventData(name: "ss", parameters: ["a":"b"], createdAt: "")
    )
    XCTAssertTrue(result)
  }*/

  func testExpressionEvaluatorFalse() {
    Storage.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "a == \"b\"",
      eventData: .stub()
    )
    XCTAssertFalse(result)
  }
}
