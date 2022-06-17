//
//  OccurrenceLogicTests.swift
//  
//
//  Created by Yusuf Tör on 17/06/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

@available(iOS 13.0, *)
class OccurrenceLogicTests: XCTestCase {
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

  func test_getCountsFromThousandsOfStoredEvents_notPreemptive() {
    let fourMinsAgo: TimeInterval = -240
    let sessionDate = Date().advanced(by: fourMinsAgo)
    let appSession = AppSession(id: "abc", startAt: sessionDate)
    let appSessionManager = AppSessionManagerMock(appSession: appSession)
    let storage = StorageMock(coreDataManager: coreDataManager)
    let eventName = "Event"

    let twoMinsAgo: TimeInterval = -120
    let firstEventDate = Date().advanced(by: twoMinsAgo)
    let firstEventData: EventData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.createdAt, to: firstEventDate)
    coreDataManager.saveEventData(firstEventData)

    for _ in 0..<10998 {
      let eventData: EventData = .stub()
        .setting(\.name, to: eventName)
      coreDataManager.saveEventData(eventData)
    }
/*
    for _ in 0..<10998 {
      let eventData: EventData = .stub()
        .setting(\.name, to: UUID().uuidString)
      coreDataManager.saveEventData(eventData)
    }*/

    let twoMinsAhead: TimeInterval = 120
    let lastEventDate = Date().advanced(by: twoMinsAhead)
    let lastEventData: EventData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.createdAt, to: lastEventDate)
    coreDataManager.saveEventData(lastEventData)

    let expectation = expectation(
      forNotification: .NSManagedObjectContextDidSave,
      object: coreDataStack.backgroundContext) { _ in
        return true
    }
    expectation.expectedFulfillmentCount = 11000
    waitForExpectations(timeout: 40.0) { error in
      XCTAssertNil(error, "Save did not occur")
    }

    var count: [String: Any] = [:]
    measure {
      count = OccurrenceLogic.getEventOccurrences(
        of: eventName,
        isPreemptive: false,
        storage: storage,
        appSessionManager: appSessionManager
      )
    }


    XCTAssertEqual(count["$count_since_install"] as? Int, 11000)
    XCTAssertEqual(count["$count_30d"] as? Int, 11000)
    XCTAssertEqual(count["$count_7d"] as? Int, 11000)
    XCTAssertEqual(count["$count_24h"] as? Int, 11000)
    XCTAssertEqual(count["$count_session"] as? Int, 11000)
    XCTAssertEqual(count["$count_today"] as? Int, 11000)
    XCTAssertEqual(count["$first_occurred_at"] as? String, firstEventData.createdAt.isoString)
    XCTAssertEqual(count["$last_occurred_at"] as? String, lastEventData.createdAt.isoString)
  }
}
