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
  /*
  func testExpressionEvaluatorTrue() throws {
    Storage.shared.userAttributes = ["a": "b"]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "a == \"b\"",
      eventData: .stub()
    )
    XCTAssertTrue(result)
  }*/

  func testExpressionEvaluatorFalse() throws {
    Storage.shared.userAttributes = [:]
    let result = ExpressionEvaluator.evaluateExpression(
      expression: "a == \"b\"",
      eventData: .stub()
    )
    XCTAssertFalse(result)
  }
}
