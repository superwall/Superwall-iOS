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
    Store.shared.clear()
  }

  func testExpressionEvaluatorTrue() throws {
    Store.shared.userAttributes = ["a": "b"]
    let result = ExpressionEvaluator.evaluateExpression(expression: "a == \"b\"")
    XCTAssertTrue(result)
  }

  func testExpressionEvaluatorFalse() throws {
    Store.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(expression: "a == \"b\"")
    XCTAssertFalse(result)
  }
}
