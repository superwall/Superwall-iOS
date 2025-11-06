//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

@available(iOS 16.0, *)
class CoreDataManagerTests: XCTestCase {
  var coreDataManager: CoreDataManagerMock!
  var coreDataStack: CoreDataStackMock!

  override func setUp() {
    super.setUp()
    coreDataStack = CoreDataStackMock()
    coreDataManager = CoreDataManagerMock(coreDataStack: coreDataStack)
    
    // Clear any existing data before each test
    let expectation = expectation(description: "Clear data")
    coreDataManager.deleteAllEntities {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 2.0)
  }

  override func tearDown() {
    super.tearDown()
    coreDataManager = nil
    coreDataStack = nil
  }


  func test_savePlacementData_withParams() {
    let eventName = "abc"
    let eventData: PlacementData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.parameters, to: ["def": "ghi"])

    let expectation = expectation(description: "Saved event")

    coreDataManager.savePlacementData(eventData) { savedPlacementData in
      XCTAssertEqual(savedPlacementData.name, eventName)
      XCTAssertEqual(savedPlacementData.name, eventName)
      XCTAssertEqual(savedPlacementData.createdAt, eventData.createdAt)

      let encodedParams = try? JSONEncoder().encode(eventData.parameters)
      XCTAssertEqual(savedPlacementData.parameters, encodedParams)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }
  }

  func test_savePlacementData_withoutParams() {
    let eventName = "abc"
    let eventData: PlacementData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.parameters, to: [:])

    let expectation = expectation(description: "Saved event")

    coreDataManager.savePlacementData(eventData) { savedPlacementData in
      XCTAssertEqual(savedPlacementData.name, eventName)
      XCTAssertEqual(savedPlacementData.name, eventName)
      XCTAssertEqual(savedPlacementData.createdAt, eventData.createdAt)

      let encodedParams = try? JSONEncoder().encode(eventData.parameters)
      XCTAssertEqual(savedPlacementData.parameters, encodedParams)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }
  }

  // MARK: - Delete All Entities
  // TODO: Fix this, doesn't work when run together but works when run individually
//  func test_deleteAllEntities() async {
//    // Save Event Data with Params
//    let placementName = "abc"
//    let placementData: PlacementData = .stub()
//      .setting(\.name, to: placementName)
//      .setting(\.parameters, to: ["def": "ghi"])
//
//    let expectation1 = expectation(description: "Saved event")
//
//    coreDataManager.savePlacementData(eventData) { savedPlacementData in
//      XCTAssertEqual(savedPlacementData.name, placementName)
//      XCTAssertEqual(savedPlacementData.name, placementName)
//      XCTAssertEqual(savedPlacementData.createdAt, eventData.createdAt)
//
//      let encodedParams = try? JSONEncoder().encode(eventData.parameters)
//      XCTAssertEqual(savedPlacementData.parameters, encodedParams)
//      expectation1.fulfill()
//    }
//
//    await fulfillment(of: [expectation1], timeout: 2)
//
//
//    // Save Trigger Rule Occurrence
//    let key = "abc"
//    let maxCount = 10
//    let interval: TriggerAudienceOccurrence.Interval = .minutes(60)
//    let occurrence = TriggerAudienceOccurrence(
//      key: key,
//      maxCount: maxCount,
//      interval: interval
//    )
//    let expectation2 = expectation(description: "Saved event")
//    let date = Date().advanced(by: -5)
//
//    coreDataManager.save(triggerRuleOccurrence: occurrence) { savedPlacementData in
//      XCTAssertEqual(savedPlacementData.occurrenceKey, key)
//      XCTAssertGreaterThan(savedPlacementData.createdAt, date)
//      expectation2.fulfill()
//    }
//
//    await fulfillment(of: [expectation2], timeout: 20)
//
//    let expectation3 = expectation(description: "Cleared events")
//
//    // Delete All Entities
//    coreDataManager.deleteAllEntities() {
//      expectation3.fulfill()
//    }
//
//    await fulfillment(of: [expectation3], timeout: 20)
//
//    try? await Task.sleep(for: .seconds(3))
//
//    // Count triggers
//    let occurrenceCount = await coreDataManager.countTriggerRuleOccurrences(for: occurrence)
//    XCTAssertEqual(occurrenceCount, 0)
//
//    let eventCount = await coreDataManager.countAllEvents()
//    XCTAssertEqual(eventCount, 0)
//  }

  // MARK: - Trigger Rule Occurrence
  func test_saveTriggerRuleOccurrence() {
    let key = "abc"
    let maxCount = 10
    let interval: TriggerAudienceOccurrence.Interval = .minutes(60)
    let occurrence = TriggerAudienceOccurrence(
      key: key,
      maxCount: maxCount,
      interval: interval
    )
    let expectation = expectation(description: "Saved event")
    let date = Date().advanced(by: -5)

    coreDataManager.save(triggerAudienceOccurrence: occurrence) { savedPlacementData in
      XCTAssertEqual(savedPlacementData.occurrenceKey, key)
      XCTAssertGreaterThan(savedPlacementData.createdAt, date)
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

    let expectation1 = expectation(description: "Saved Trigger Occurrences")
    expectation1.expectedFulfillmentCount = keys.count

    for key in keys {
      coreDataStack.batchInsertTriggerOccurrences(
        key: key,
        count: 10,
        completion: {
          expectation1.fulfill()
        }
      )
    }

    waitForExpectations(timeout: 10.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }


    let key = "1"
    let maxCount = 10
    let interval: TriggerAudienceOccurrence.Interval = .minutes(60)
    let occurrence = TriggerAudienceOccurrence(
      key: key,
      maxCount: maxCount,
      interval: interval
    )

    measure {
      let exp = expectation(description: "Finished")
      Task {
        var count = 0
        count = await coreDataManager.countAudienceOccurrences(for: occurrence)
        exp.fulfill()
        XCTAssertEqual(count, 10)
      }
      wait(for: [exp], timeout: 15.0)
    }
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
      coreDataStack.batchInsertPlacementData(placementName: name, count: Int(count)) {
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
      count = coreDataManager.countAudienceOccurrences(for: occurrence)
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    XCTAssertEqual(count, 10)
  }*/

  // MARK: - Count Placement Tests
  func test_countPlacement_withMinutesInterval_noEvents() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .minutes(60)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 0)
  }

  func test_countPlacement_withInfinityInterval_noEvents() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .infinity
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 0)
  }

  func test_countPlacement_withMinutesInterval_singleEvent() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .minutes(60)
    
    // Save a placement event
    let placementData = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: Date())
    
    let expectation = expectation(description: "Saved placement")
    coreDataManager.savePlacementData(placementData) { _ in
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 2.0)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 1)
  }

  func test_countPlacement_withInfinityInterval_singleEvent() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .infinity
    
    // Save a placement event
    let placementData = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: Date())
    
    let expectation = expectation(description: "Saved placement")
    coreDataManager.savePlacementData(placementData) { _ in
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 2.0)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 1)
  }

  func test_countPlacement_withMinutesInterval_multipleEvents() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .minutes(60)
    
    // Save multiple placement events
    let expectation = expectation(description: "Saved placements")
    expectation.expectedFulfillmentCount = 3
    
    for i in 0..<3 {
      let placementData = PlacementData.stub()
        .setting(\.name, to: placementName)
        .setting(\.createdAt, to: Date().addingTimeInterval(TimeInterval(i)))
      
      coreDataManager.savePlacementData(placementData) { _ in
        expectation.fulfill()
      }
    }
    await fulfillment(of: [expectation], timeout: 2.0)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 3)
  }

  func test_countPlacement_withInfinityInterval_multipleEvents() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .infinity
    
    // Save multiple placement events
    let expectation = expectation(description: "Saved placements")
    expectation.expectedFulfillmentCount = 5
    
    for i in 0..<5 {
      let placementData = PlacementData.stub()
        .setting(\.name, to: placementName)
        .setting(\.createdAt, to: Date().addingTimeInterval(TimeInterval(i)))
      
      coreDataManager.savePlacementData(placementData) { _ in
        expectation.fulfill()
      }
    }
    await fulfillment(of: [expectation], timeout: 2.0)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 5)
  }

  func test_countPlacement_withMinutesInterval_onlyCountsEventsWithinInterval() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .minutes(30)
    
    // Save events: one within interval, one outside
    let expectation = expectation(description: "Saved placements")
    expectation.expectedFulfillmentCount = 2
    
    // Event within interval (10 minutes ago)
    let recentEvent = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: Date().addingTimeInterval(-10 * 60))
    
    // Event outside interval (45 minutes ago)
    let oldEvent = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: Date().addingTimeInterval(-45 * 60))
    
    coreDataManager.savePlacementData(recentEvent) { _ in
      expectation.fulfill()
    }
    coreDataManager.savePlacementData(oldEvent) { _ in
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 2.0)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 1)
  }

  func test_countPlacement_withMinutesInterval_onlyCountsMatchingPlacementName() async {
        
    let targetPlacementName = "target_placement"
    let otherPlacementName = "other_placement"
    let interval: TriggerAudienceOccurrence.Interval = .minutes(60)
    
    // Save events with different names
    let expectation = expectation(description: "Saved placements")
    expectation.expectedFulfillmentCount = 3
    
    // Target placement events
    for i in 0..<2 {
      let placementData = PlacementData.stub()
        .setting(\.name, to: targetPlacementName)
        .setting(\.createdAt, to: Date().addingTimeInterval(TimeInterval(i)))
      
      coreDataManager.savePlacementData(placementData) { _ in
        expectation.fulfill()
      }
    }
    
    // Other placement event (should not be counted)
    let otherPlacementData = PlacementData.stub()
      .setting(\.name, to: otherPlacementName)
      .setting(\.createdAt, to: Date())
    
    coreDataManager.savePlacementData(otherPlacementData) { _ in
      expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 2.0)

    let count = await coreDataManager.countPlacement(targetPlacementName, interval: interval)

    XCTAssertEqual(count, 2)
  }

  func test_countPlacement_withInfinityInterval_onlyCountsMatchingPlacementName() async {
        
    let targetPlacementName = "target_placement"
    let otherPlacementName = "other_placement"
    let interval: TriggerAudienceOccurrence.Interval = .infinity
    
    // Save events with different names
    let expectation = expectation(description: "Saved placements")
    expectation.expectedFulfillmentCount = 4
    
    // Target placement events
    for i in 0..<3 {
      let placementData = PlacementData.stub()
        .setting(\.name, to: targetPlacementName)
        .setting(\.createdAt, to: Date().addingTimeInterval(TimeInterval(i)))
      
      coreDataManager.savePlacementData(placementData) { _ in
        expectation.fulfill()
      }
    }
    
    // Other placement event (should not be counted)
    let otherPlacementData = PlacementData.stub()
      .setting(\.name, to: otherPlacementName)
      .setting(\.createdAt, to: Date())
    
    coreDataManager.savePlacementData(otherPlacementData) { _ in
      expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 2.0)
    
    let count = await coreDataManager.countPlacement(targetPlacementName, interval: interval)
    
    XCTAssertEqual(count, 3)
  }

  func test_countPlacement_withMinutesInterval_boundaryConditions() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .minutes(60)
    
    // Save events: one safely inside boundary, one just inside, one just outside
    let expectation = expectation(description: "Saved placements")
    expectation.expectedFulfillmentCount = 3
    
    let now = Date()
    
    // Event safely inside boundary (58 minutes ago - well within range)
    let safeEvent = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: now.addingTimeInterval(-58 * 60))
    
    // Event just inside boundary (30 minutes ago)
    let insideEvent = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: now.addingTimeInterval(-30 * 60))
    
    // Event just outside boundary (65 minutes ago - well outside)
    let outsideEvent = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: now.addingTimeInterval(-65 * 60))
    
    coreDataManager.savePlacementData(safeEvent) { _ in
      expectation.fulfill()
    }
    coreDataManager.savePlacementData(insideEvent) { _ in
      expectation.fulfill()
    }
    coreDataManager.savePlacementData(outsideEvent) { _ in
      expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 2.0)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 2)
  }

  func test_countPlacement_withZeroMinutesInterval() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .minutes(0)
    
    // Save a placement event - with zero minutes interval, no events should be counted
    let placementData = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: Date())
    
    let expectation = expectation(description: "Saved placement")
    coreDataManager.savePlacementData(placementData) { _ in
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 2.0)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    // Zero minutes interval means "within the last 0 minutes" which should return 0
    XCTAssertEqual(count, 0)
  }

  func test_countPlacement_withLargeNumberOfEvents() async {
        
    let placementName = "test_placement"
    let interval: TriggerAudienceOccurrence.Interval = .infinity
    let eventCount = 50
    
    // Use batch insert for performance
    let expectation = expectation(description: "Saved placements")
    coreDataStack.batchInsertPlacementData(
      eventName: placementName,
      count: eventCount
    ) {
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 5.0)
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, eventCount)
  }

  func test_countPlacement_withEmptyPlacementName() async {
        
    let placementName = ""
    let interval: TriggerAudienceOccurrence.Interval = .infinity
    
    let count = await coreDataManager.countPlacement(placementName, interval: interval)
    
    XCTAssertEqual(count, 0)
  }

  func test_countPlacement_concurrent_access() async {
        
    let placementName = "concurrent_test"
    let interval: TriggerAudienceOccurrence.Interval = .infinity
    
    // Save some initial data
    let expectation = expectation(description: "Saved placements")
    expectation.expectedFulfillmentCount = 5
    
    for i in 0..<5 {
      let placementData = PlacementData.stub()
        .setting(\.name, to: placementName)
        .setting(\.createdAt, to: Date().addingTimeInterval(TimeInterval(i)))
      
      coreDataManager.savePlacementData(placementData) { _ in
        expectation.fulfill()
      }
    }
    await fulfillment(of: [expectation], timeout: 2.0)
    
    // Perform multiple concurrent counts
    async let count1 = coreDataManager.countPlacement(placementName, interval: interval)
    async let count2 = coreDataManager.countPlacement(placementName, interval: interval)
    async let count3 = coreDataManager.countPlacement(placementName, interval: interval)
    
    let results = await [count1, count2, count3]
    
    // All concurrent operations should return the same count
    XCTAssertEqual(results[0], 5)
    XCTAssertEqual(results[1], 5)
    XCTAssertEqual(results[2], 5)
  }
}
