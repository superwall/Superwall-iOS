//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

@available(iOS 14.0, *)
class CoreDataManagerTests: XCTestCase {
  var coreDataManager: CoreDataManagerMock!
  var coreDataStack: CoreDataStackMock!

  override func setUp() {
    super.setUp()
    coreDataStack = CoreDataStackMock()
    coreDataManager = CoreDataManagerMock(coreDataStack: coreDataStack)
  }

  override func tearDown() {
    super.tearDown()
    coreDataManager = nil
    coreDataStack = nil
  }

  func test_saveEventData_withParams() {
    let eventName = "abc"
    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.parameters, to: ["def": "ghi"])

    let expectation = expectation(description: "Saved event")

    coreDataManager.saveEventData(eventData) { savedEventData in
      XCTAssertEqual(savedEventData.name, eventName)
      XCTAssertEqual(savedEventData.name, eventName)
      XCTAssertEqual(savedEventData.createdAt, eventData.createdAt)

      let encodedParams = try? JSONEncoder().encode(eventData.parameters)
      XCTAssertEqual(savedEventData.parameters, encodedParams)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }
  }

  func test_saveEventData_withoutParams() {
    let eventName = "abc"
    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.parameters, to: [:])

    let expectation = expectation(description: "Saved event")

    coreDataManager.saveEventData(eventData) { savedEventData in
      XCTAssertEqual(savedEventData.name, eventName)
      XCTAssertEqual(savedEventData.name, eventName)
      XCTAssertEqual(savedEventData.createdAt, eventData.createdAt)

      let encodedParams = try? JSONEncoder().encode(eventData.parameters)
      XCTAssertEqual(savedEventData.parameters, encodedParams)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }
  }

  // MARK: - Delete All Entities
  func test_deleteAllEntities() {
    // Save Event Data with Params
    let eventName = "abc"
    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.parameters, to: ["def": "ghi"])

    let expectation1 = expectation(description: "Saved event")

    coreDataManager.saveEventData(eventData) { savedEventData in
      XCTAssertEqual(savedEventData.name, eventName)
      XCTAssertEqual(savedEventData.name, eventName)
      XCTAssertEqual(savedEventData.createdAt, eventData.createdAt)

      let encodedParams = try? JSONEncoder().encode(eventData.parameters)
      XCTAssertEqual(savedEventData.parameters, encodedParams)
      expectation1.fulfill()
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }


    // Save Trigger Rule Occurrence
    let key = "abc"
    let maxCount = 10
    let interval: TriggerRuleOccurrence.Interval = .minutes(60)
    let occurrence = TriggerRuleOccurrence(
      key: key,
      maxCount: maxCount,
      interval: interval
    )
    let expectation2 = expectation(description: "Saved event")
    let date = Date().advanced(by: -5)

    coreDataManager.save(triggerRuleOccurrence: occurrence) { savedEventData in
      XCTAssertEqual(savedEventData.occurrenceKey, key)
      XCTAssertGreaterThan(savedEventData.createdAt, date)
      expectation2.fulfill()
    }

    waitForExpectations(timeout: 20.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    // Delete All Entities
    let expectation3 = expectation(description: "Delete entities")
    coreDataManager.deleteAllEntities() {
      expectation3.fulfill()
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    // Count triggers
    let occurrenceCount = coreDataManager.countTriggerRuleOccurrences(for: occurrence)
    XCTAssertEqual(occurrenceCount, 0)

    let eventCount = coreDataManager.countAllEvents()
    XCTAssertEqual(eventCount, 0)
  }

  // MARK: - Trigger Rule Occurrence
  func test_saveTriggerRuleOccurrence() {
    let key = "abc"
    let maxCount = 10
    let interval: TriggerRuleOccurrence.Interval = .minutes(60)
    let occurrence = TriggerRuleOccurrence(
      key: key,
      maxCount: maxCount,
      interval: interval
    )
    let expectation = expectation(description: "Saved event")
    let date = Date().advanced(by: -5)

    coreDataManager.save(triggerRuleOccurrence: occurrence) { savedEventData in
      XCTAssertEqual(savedEventData.occurrenceKey, key)
      XCTAssertGreaterThan(savedEventData.createdAt, date)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 20.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }
  }

  func test_countTriggerRuleOccurrences_minutes() {
    var keys: [String] = []
    for i in 0..<200 {
      keys.append("\(i)")
    }

    let expectation = expectation(description: "Saved Trigger Occurrences")
    expectation.expectedFulfillmentCount = keys.count

    for key in keys {
      coreDataStack.batchInsertTriggerOccurrences(
        key: key,
        count: 10,
        completion: {
          expectation.fulfill()
        }
      )
    }

    waitForExpectations(timeout: 10.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }


    let key = "1"
    let maxCount = 10
    let interval: TriggerRuleOccurrence.Interval = .minutes(60)
    let occurrence = TriggerRuleOccurrence(
      key: key,
      maxCount: maxCount,
      interval: interval
    )

    var count = 0
    measure {
      count = coreDataManager.countTriggerRuleOccurrences(for: occurrence)
    }

    XCTAssertEqual(count, 10)
  }

  /*
   uncomments to test count of trigger rule occurrence with loads of events
  func test_countTriggerRuleOccurrences_loadsOfEvents() {
    var names: [String] = []
    for i in 0..<200 {
      names.append("\(i)")
    }

    let expectation1 = expectation(description: "Saved Event")
    expectation1.expectedFulfillmentCount = names.count


    for i in 0..<names.count {
      let name = names[i]
      let count = 1000.0/(2.0*(Double(i)+1.0))
      print("COUNT is ", count)
      coreDataStack.batchInsertEventData(eventName: name, count: Int(count)) {
        expectation1.fulfill()
      }
    }

    waitForExpectations(timeout: 50.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    var keys: [String] = []
    for i in 0..<400 {
      keys.append("\(i)")
    }

    let expectation2 = expectation(description: "Saved Trigger Occurrences")
    expectation2.expectedFulfillmentCount = keys.count

    for key in keys {
      coreDataStack.batchInsertTriggerOccurrences(
        key: key,
        count: 250,
        completion: {
          expectation2.fulfill()
        }
      )
    }

    let key = "1"
    let maxCount = 10
    let interval: TriggerRuleOccurrence.Interval = .minutes(60)
    let occurrence = TriggerRuleOccurrence(
      key: key,
      maxCount: maxCount,
      interval: interval
    )

    var count = 0
    measure {
      count = coreDataManager.countTriggerRuleOccurrences(for: occurrence)
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    XCTAssertEqual(count, 10)
  }*/
}
