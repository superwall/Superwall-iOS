//
//  CoreDataManagerTests.swift
//  
//
//  Created by Yusuf Tör on 17/06/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

@available(iOS 13.0, *)
class CoreDataManagerTests: XCTestCase {
  var coreDataManager: CoreDataManager!
  var coreDataStack: CoreDataStack!

  override func setUp() {
    super.setUp()
    coreDataStack = CoreDataStackMock()
    coreDataManager = CoreDataManager(coreDataStack: coreDataStack)
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

    coreDataManager.saveEventData(eventData) { savedEvent in
      XCTAssertEqual(savedEvent.name, eventName)
      let savedEventData = savedEvent.data?.firstObject as! ManagedEventData

      XCTAssertEqual(savedEventData.id, eventData.id)
      XCTAssertEqual(savedEventData.name, eventName)
      XCTAssertEqual(savedEventData.createdAt, eventData.createdAt)

      let encodedParams = try? JSONEncoder().encode(eventData.parameters)
      XCTAssertEqual(savedEventData.parameters, encodedParams)
    }

    expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
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

    coreDataManager.saveEventData(eventData) { savedEvent in
      XCTAssertEqual(savedEvent.name, eventName)
      let savedEventData = savedEvent.data?.firstObject as! ManagedEventData

      XCTAssertEqual(savedEventData.id, eventData.id)
      XCTAssertEqual(savedEventData.name, eventName)
      XCTAssertEqual(savedEventData.createdAt, eventData.createdAt)

      let encodedParams = try? JSONEncoder().encode(eventData.parameters)
      XCTAssertEqual(savedEventData.parameters, encodedParams)
    }

    expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }
  }

  func test_getAllEventNames() {
    let eventName1 = "Event1"
    let eventData1: EventData = .stub()
      .setting(\.name, to: eventName1)

    coreDataManager.saveEventData(eventData1)

    let eventName2 = "Event2"
    let eventData2: EventData = .stub()
      .setting(\.name, to: eventName2)
    coreDataManager.saveEventData(eventData2)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 2

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let allEventNames = coreDataManager.getAllEventNames()
    XCTAssertTrue(allEventNames.contains(eventName1))
    XCTAssertTrue(allEventNames.contains(eventName2))
  }

  // MARK: - Count Since
  func test_countSinceInstall_isntPreemptive() {
    let eventName1 = "Event1"
    let eventData1: EventData = .stub()
      .setting(\.name, to: eventName1)

    coreDataManager.saveEventData(eventData1)

    let eventName2 = "Event1"
    let eventData2: EventData = .stub()
      .setting(\.name, to: eventName2)
    coreDataManager.saveEventData(eventData2)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let count = coreDataManager.countSinceInstall(ofEvent: eventName1, isPreemptive: false)
    XCTAssertEqual(count, 2)
  }

  func test_countSinceInstall_isPreemptive() {
    let eventName1 = "Event1"
    let eventData1: EventData = .stub()
      .setting(\.name, to: eventName1)

    coreDataManager.saveEventData(eventData1)

    let eventName2 = "Event1"
    let eventData2: EventData = .stub()
      .setting(\.name, to: eventName2)
    coreDataManager.saveEventData(eventData2)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let count = coreDataManager.countSinceInstall(ofEvent: eventName1, isPreemptive: true)
    XCTAssertEqual(count, 3)
  }

  func test_countToday_isntPreemptive() {
    let eventName1 = "Event"
    let twentyFiveHoursAgo: TimeInterval = -25 * 60 * 60

    let oldEventData: EventData = .stub()
      .setting(\.name, to: eventName1)
      .setting(\.createdAt, to: Date().advanced(by: twentyFiveHoursAgo))

    coreDataManager.saveEventData(oldEventData)

    let eventName2 = "Event"
    let eventData2: EventData = .stub()
      .setting(\.name, to: eventName2)
    coreDataManager.saveEventData(eventData2)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let count = coreDataManager.count(ofEvent: "Event", in: .today, isPreemptive: false)
    XCTAssertEqual(count, 1)
  }

  func test_countToday_isPreemptive() {
    let eventName1 = "Event"
    let twentyFiveHoursAgo: TimeInterval = -25 * 60 * 60

    let oldEventData: EventData = .stub()
      .setting(\.name, to: eventName1)
      .setting(\.createdAt, to: Date().advanced(by: twentyFiveHoursAgo))

    coreDataManager.saveEventData(oldEventData)

    let eventName2 = "Event"
    let eventData2: EventData = .stub()
      .setting(\.name, to: eventName2)
    coreDataManager.saveEventData(eventData2)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let count = coreDataManager.count(ofEvent: "Event", in: .today, isPreemptive: true)
    XCTAssertEqual(count, 2)
  }

  func test_countLastThirtyDays_isntPreemptive() {
    let eventName1 = "Event"
    let thirtyOneDaysAgo: TimeInterval = -31 * 24 * 60 * 60

    let oldEventData: EventData = .stub()
      .setting(\.name, to: eventName1)
      .setting(\.createdAt, to: Date().advanced(by: thirtyOneDaysAgo))

    coreDataManager.saveEventData(oldEventData)

    let eventName2 = "Event"
    let twentyFiveHoursAgo: TimeInterval = -25 * 60 * 60
    let eventData2: EventData = .stub()
      .setting(\.name, to: eventName2)
      .setting(\.createdAt, to: Date().advanced(by: twentyFiveHoursAgo))
    coreDataManager.saveEventData(eventData2)

    let eventName3 = "Event"
    let eightDaysAgo: TimeInterval = -8 * 24 * 60 * 60
    let eventData3: EventData = .stub()
      .setting(\.name, to: eventName3)
      .setting(\.createdAt, to: Date().advanced(by: eightDaysAgo))
    coreDataManager.saveEventData(eventData3)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let count = coreDataManager.count(ofEvent: "Event", in: .thirtyDays, isPreemptive: false)
    XCTAssertEqual(count, 2)
  }

  func test_countLastSevenDays_isntPreemptive() {
    let eventName1 = "Event"
    let eightDaysAgo: TimeInterval = -8 * 24 * 60 * 60

    let oldEventData: EventData = .stub()
      .setting(\.name, to: eventName1)
      .setting(\.createdAt, to: Date().advanced(by: eightDaysAgo))

    coreDataManager.saveEventData(oldEventData)

    let eventName2 = "Event"
    let twentyFiveHoursAgo: TimeInterval = -25 * 60 * 60
    let eventData2: EventData = .stub()
      .setting(\.name, to: eventName2)
      .setting(\.createdAt, to: Date().advanced(by: twentyFiveHoursAgo))
    coreDataManager.saveEventData(eventData2)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let count = coreDataManager.count(ofEvent: "Event", in: .sevenDays, isPreemptive: false)
    XCTAssertEqual(count, 1)
  }

  func test_countLastSession_isntPreemptive() {
    let eventName1 = "Event"
    let twoMinsAgo: TimeInterval = -120

    let oldEventData: EventData = .stub()
      .setting(\.name, to: eventName1)
      .setting(\.createdAt, to: AppSessionManager.shared.appSession.startAt.advanced(by: twoMinsAgo))

    coreDataManager.saveEventData(oldEventData)

    let eventName2 = "Event"
    let eventData2: EventData = .stub()
      .setting(\.name, to: eventName2)
    coreDataManager.saveEventData(eventData2)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let count = coreDataManager.count(
      ofEvent: "Event",
      in: .lastSession(appSessionStartAt: AppSessionManager.shared.appSession.startAt),
      isPreemptive: false
    )
    XCTAssertEqual(count, 1)
  }

  func test_isoDateOfFirstEvent_isntPreemptive() {
    let eventName = "Event"
    let twoMinsAgo: TimeInterval = -120
    let date = Date().advanced(by: twoMinsAgo)

    let oldEventData: EventData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.createdAt, to: date)

    coreDataManager.saveEventData(oldEventData)

    for _ in 0..<10 {
      let eventData2: EventData = .stub()
        .setting(\.name, to: eventName)
      coreDataManager.saveEventData(eventData2)
    }

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let isoDate = coreDataManager.getIsoDateOfEventOccurrence(
      withName: eventName,
      position: .first
    )
    XCTAssertEqual(isoDate, date.isoString)
  }

  func test_isoDateOfFirstEvent_isPreemptive() {
    let eventName = "Event"
    let twoMinsAgo: TimeInterval = -120
    let date = Date().advanced(by: twoMinsAgo)

    let isoDate = coreDataManager.getIsoDateOfEventOccurrence(
      withName: eventName,
      position: .first,
      newEventDate: date
    )

    XCTAssertEqual(isoDate, date.isoString)
  }

  func test_isoDateOfLastEntity_isntPreemptive() {
    let eventName1 = "Event"
    let twoMinsAgo: TimeInterval = -120
    let date = Date().advanced(by: twoMinsAgo)

    for _ in 0..<10 {
      let eventName2 = "Event"
      let eventData2: EventData = .stub()
        .setting(\.name, to: eventName2)
        .setting(\.createdAt, to: date)
      coreDataManager.saveEventData(eventData2)
    }

    let newEventData: EventData = .stub()
      .setting(\.name, to: eventName1)

    coreDataManager.saveEventData(newEventData)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 1

    waitForExpectations(timeout: 2.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    let isoDate = coreDataManager.getIsoDateOfEventOccurrence(
      withName: "Event",
      position: .last
    )
    XCTAssertEqual(isoDate, newEventData.createdAt.isoString)
  }

  func test_isoDateOfLastEvent_isPreemptive() {
    let eventName = "Event"
    let twoMinsAgo: TimeInterval = -120
    let date = Date().advanced(by: twoMinsAgo)

    let isoDate = coreDataManager.getIsoDateOfEventOccurrence(
      withName: eventName,
      position: .last,
      newEventDate: date
    )

    XCTAssertEqual(isoDate, date.isoString)
  }
}
