//
//  OccurrenceLogicTests.swift
//
//
//  Created by Yusuf Tör on 17/06/2022.
//
// swiftlint:disable all

// ONLY TEST THIS MANUALLY, DON'T PUSH TO SERVER AS IT TAKES A LONG TIME:
/*
import Testing
@testable import SuperwallKit

@available(iOS 14.0, *)
class OccurrenceLogicTests {
  var coreDataManager: CoreDataManager!
  var coreDataStack: CoreDataStackMock!
  let eventName = "SuperwallEvent"

  init() {
    coreDataStack = CoreDataStackMock()
    coreDataManager = CoreDataManager(coreDataStack: coreDataStack)
  }

  deinit {
    coreDataStack.deleteAllEntities(named: "PlacementData")
    coreDataManager = nil
    coreDataStack = nil
  }

  @Test func getCountsFromThousandsOfStoredEvents_notPreemptive() {
    let fourMinsAgo: TimeInterval = -240
    let sessionDate = Date().advanced(by: fourMinsAgo)
    let appSession = AppSession(id: "abc", startAt: sessionDate)
    let appSessionManager = AppSessionManagerMock(appSession: appSession)
    let storage = StorageMock(coreDataManager: coreDataManager)


    var arrayOfNames: [String] = []
    for _ in 0..<200 {
      let randomString = UUID().uuidString
      arrayOfNames.append(randomString)
    }

/*
    let twoMinsAgo: TimeInterval = -120
    let firstEventDate = Date().advanced(by: twoMinsAgo)
    let firstPlacementData: PlacementData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.createdAt, to: firstEventDate)
    coreDataManager.savePlacementData(firstPlacementData) { _ in
    }*/
    var percentage: Double = 1 / 2
    var total = 0
    for name in arrayOfNames {
      let count = Int(1000000 * percentage)
      total += count
      coreDataStack.batchInsertPlacementData(eventName: name, count: count) {
      }
      percentage = percentage / 2
    }
    print(total)
/*
    let twoMinsAhead: TimeInterval = 120
    let lastEventDate = Date().advanced(by: twoMinsAhead)
    let lastPlacementData: PlacementData = .stub()
      .setting(\.name, to: eventName)
      .setting(\.createdAt, to: lastEventDate)
    coreDataManager.savePlacementData(lastPlacementData) { _ in
    }*/

    print("************")
    var count: [String: Any] = [:]
    var eventOccurrences: [String: [String: Any]] = [:]
    let eventNames = storage.coreDataManager.getAllEventNames()

    for eventName in eventNames {
      eventOccurrences[eventName] = OccurrenceLogic.getEventOccurrences(
        of: eventName,
        isPreemptive: false,
        storage: storage,
        appSessionManager: appSessionManager
      )
    }

    print("************")
    #expect(count["$count_since_install"] as? Int == 11000)
    #expect(count["$count_30d"] as? Int == 11000)
    #expect(count["$count_7d"] as? Int == 11000)
    #expect(count["$count_24h"] as? Int == 11000)
    #expect(count["$count_session"] as? Int == 11000)
    #expect(count["$count_today"] as? Int == 11000)
   // #expect(count["$first_occurred_at"] as? String == firstPlacementData.createdAt.isoString)
   // #expect(count["$last_occurred_at"] as? String == lastPlacementData.createdAt.isoString)
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
*/
