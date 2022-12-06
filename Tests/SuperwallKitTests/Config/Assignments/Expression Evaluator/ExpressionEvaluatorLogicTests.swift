//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/07/2022.
//

import Foundation
import XCTest
@testable import SuperwallKit

@available(iOS 14.0, *)
final class ExpressionEvaluatorLogicTests: XCTestCase {
  func testShouldFire_noMatch() {
    let storage = StorageMock()
    let shouldFire = ExpressionEvaluatorLogic.shouldFire(
      forOccurrence: .stub(),
      ruleMatched: false,
      storage: storage,
      isPreemptive: false
    )
    XCTAssertFalse(shouldFire)
  }

  func testShouldFire_noOccurrenceRule() {
    let storage = StorageMock()
    let shouldFire = ExpressionEvaluatorLogic.shouldFire(
      forOccurrence: nil,
      ruleMatched: true,
      storage: storage,
      isPreemptive: false
    )
    XCTAssertTrue(shouldFire)
  }

  func testShouldFire_shouldntFire_maxCountGTCount() {
    let coreDataManagerMock = CoreDataManagerFakeDataMock(internalOccurrenceCount: 1)
    let storage = StorageMock(coreDataManager: coreDataManagerMock)
    let shouldFire = ExpressionEvaluatorLogic.shouldFire(
      forOccurrence: .stub()
        .setting(\.maxCount, to: 1),
      ruleMatched: true,
      storage: storage,
      isPreemptive: false
    )
    XCTAssertFalse(shouldFire)
  }

  func testShouldFire_shouldFire_maxCountEqualToCount() {
    let coreDataManagerMock = CoreDataManagerFakeDataMock(internalOccurrenceCount: 0)
    let storage = StorageMock(coreDataManager: coreDataManagerMock)
    let shouldFire = ExpressionEvaluatorLogic.shouldFire(
      forOccurrence: .stub()
        .setting(\.maxCount, to: 1),
      ruleMatched: true,
      storage: storage,
      isPreemptive: false
    )
    XCTAssertTrue(shouldFire)
  }

  func testShouldFire_shouldFire_maxCountLtCount() {
    let coreDataManagerMock = CoreDataManagerFakeDataMock(internalOccurrenceCount: 1)
    let storage = StorageMock(coreDataManager: coreDataManagerMock)
    let shouldFire = ExpressionEvaluatorLogic.shouldFire(
      forOccurrence: .stub()
        .setting(\.maxCount, to: 4),
      ruleMatched: true,
      storage: storage,
      isPreemptive: false
    )
    XCTAssertTrue(shouldFire)
  }
}
