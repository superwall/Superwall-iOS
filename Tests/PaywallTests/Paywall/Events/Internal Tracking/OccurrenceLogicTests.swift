//
//  OccurrenceLogicTests.swift
//  
//
//  Created by Yusuf Tör on 17/06/2022.
//
// swiftlint:disable all

// ONLY TEST THIS MANUALLY, DON'T PUSH TO SERVER AS IT TAKES A LONG TIME:

import XCTest
@testable import Paywall

@available(iOS 14.0, *)
class OccurrenceLogicTests: XCTestCase {
  var coreDataManager: CoreDataManager!
  var coreDataStack: CoreDataStackMock!
  let eventName = "EventName"

  override func setUp() {
    super.setUp()
    coreDataStack = CoreDataStackMock()
    coreDataManager = CoreDataManager(coreDataStack: coreDataStack)
  }

  override func tearDown() {
    super.tearDown()
    coreDataStack.deleteAllEntities(named: "EventData")
    coreDataManager = nil
    coreDataStack = nil
  }

  func test_getCountsFromThousandsOfStoredEvents_notPreemptive() {
    let fourMinsAgo: TimeInterval = -240
    let sessionDate = Date().advanced(by: fourMinsAgo)
    let appSession = AppSession(id: "abc", startAt: sessionDate)
    let appSessionManager = AppSessionManagerMock(appSession: appSession)
    let storage = StorageMock(coreDataManager: coreDataManager)


    let arrayOfNames = ["Event", "Bob", "jim", "mate", "yo"]

    let expectation = expectation(description: "Saved Event")
    expectation.expectedFulfillmentCount = arrayOfNames.count
/*
    let twoMinsAgo: TimeInterval = -120
    let firstEventDate = Date().advanced(by: twoMinsAgo)
    let firstEventData: EventData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.createdAt, to: firstEventDate)
    coreDataManager.saveEventData(firstEventData) { _ in
      expectation.fulfill()
    }*/

    for name in arrayOfNames {
      coreDataStack.batchInsertEventData(eventName: name, count: 1000) {
        expectation.fulfill()
      }
    }
/*
    let twoMinsAhead: TimeInterval = 120
    let lastEventDate = Date().advanced(by: twoMinsAhead)
    let lastEventData: EventData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.createdAt, to: lastEventDate)
    coreDataManager.saveEventData(lastEventData) { _ in
      expectation.fulfill()
    }*/

    waitForExpectations(timeout: 10.0) { error in
      XCTAssertNil(error)
    }
    print("************")
    var count: [String: Any] = [:]
    let options = XCTMeasureOptions()
    options.iterationCount = 1
    measure(options: options) {
      count = OccurrenceLogic.getEventOccurrences(
        of: arrayOfNames[0],
        isPreemptive: false,
        storage: storage,
        appSessionManager: appSessionManager
      )
    }

    print("************")
    XCTAssertEqual(count["$count_since_install"] as? Int, 11000)
    XCTAssertEqual(count["$count_30d"] as? Int, 11000)
    XCTAssertEqual(count["$count_7d"] as? Int, 11000)
    XCTAssertEqual(count["$count_24h"] as? Int, 11000)
    XCTAssertEqual(count["$count_session"] as? Int, 11000)
    XCTAssertEqual(count["$count_today"] as? Int, 11000)
   // XCTAssertEqual(count["$first_occurred_at"] as? String, firstEventData.createdAt.isoString)
   // XCTAssertEqual(count["$last_occurred_at"] as? String, lastEventData.createdAt.isoString)
  }
}


/*
 Results for 5M entries (all of same name) to get eventOccurrences

 Total:
 5M = 1.96s (avg. of ten: 1.9246s)

 


 Just firstOccurred:
 5M = 0.242 (avg. of ten: 0.210s)

 Just lastOccurred:
 5M = 0.243 (avg. of ten: 0.209s)
*/
