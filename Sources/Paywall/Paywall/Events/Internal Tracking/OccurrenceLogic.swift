//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/06/2022.
//

import Foundation

enum OccurrenceLogic {
  /// Called in advance of an event being tracked. Therefore we return values as if the event is already tracked.
  static func getEventOccurrences(
    of eventName: String,
    isPreemptive: Bool,
    eventCreatedAt: Date? = nil,
    storage: Storage = Storage.shared,
    appSessionManager: AppSessionManager = AppSessionManager.shared
  ) -> [String: Any] {
    let dispatchGroup = DispatchGroup()

    dispatchGroup.enter()
    var countSinceInstall = 0
    storage.coreDataManager.countSinceInstall(
      ofEvent: eventName,
      isPreemptive: isPreemptive
    ) { count in
      countSinceInstall = count
      dispatchGroup.leave()
    }

    dispatchGroup.enter()
    var countThirtyDays = 0
    storage.coreDataManager.count(
      ofEvent: eventName,
      in: .thirtyDays,
      isPreemptive: isPreemptive
    ) { count in
      countThirtyDays = count
      dispatchGroup.leave()
    }

    dispatchGroup.enter()
    var countSevenDays = 0
    storage.coreDataManager.count(
      ofEvent: eventName,
      in: .sevenDays,
      isPreemptive: isPreemptive
    ) { count in
      countSevenDays = count
      dispatchGroup.leave()
    }

    dispatchGroup.enter()
    var countTwentyFourHours = 0
    storage.coreDataManager.count(
      ofEvent: eventName,
      in: .twentyFourHours,
      isPreemptive: isPreemptive
    ) { count in
      countTwentyFourHours = count
      dispatchGroup.leave()
    }

    dispatchGroup.enter()
    var countSession = 0
    storage.coreDataManager.count(
      ofEvent: eventName,
      in: .lastSession(appSessionStartAt: appSessionManager.appSession.startAt),
      isPreemptive: isPreemptive
    ) { count in
      countSession = count
      dispatchGroup.leave()
    }

    dispatchGroup.enter()
    var countToday = 0
    storage.coreDataManager.count(
      ofEvent: eventName,
      in: .today,
      isPreemptive: isPreemptive
    ) { count in
      countToday = count
      dispatchGroup.leave()
    }

    dispatchGroup.enter()
    var firstOccurredAt = ""
    storage.coreDataManager.getIsoDateOfEventOccurrence(
      withName: eventName,
      position: .first,
      newEventDate: eventCreatedAt
    ) { dateString in
      firstOccurredAt = dateString
      dispatchGroup.leave()
    }

    dispatchGroup.enter()
    var lastOccurredAt = ""
    storage.coreDataManager.getIsoDateOfEventOccurrence(
      withName: eventName,
      position: .last,
      newEventDate: eventCreatedAt
    ) { dateString in
      lastOccurredAt = dateString
      dispatchGroup.leave()
    }

    dispatchGroup.wait()
    return [
      "$count_since_install": countSinceInstall,
      "$count_30d": countThirtyDays,
      "$count_7d": countSevenDays,
      "$count_24h": countTwentyFourHours,
      "$count_session": countSession,
      "$count_today": countToday,
      "$first_occurred_at": firstOccurredAt,
      "$last_occurred_at": lastOccurredAt
    ]

    /*return [
      "$count_since_install": storage.coreDataManager.countSinceInstall(
        ofEvent: eventName,
        isPreemptive: isPreemptive
      ),
      "$count_30d": storage.coreDataManager.count(
        ofEvent: eventName,
        in: .thirtyDays,
        isPreemptive: isPreemptive
      ),
      "$count_7d": storage.coreDataManager.count(
        ofEvent: eventName,
        in: .sevenDays,
        isPreemptive: isPreemptive
      ),
      "$count_24h": storage.coreDataManager.count(
        ofEvent: eventName,
        in: .twentyFourHours,
        isPreemptive: isPreemptive
      ),
      "$count_session": storage.coreDataManager.count(
        ofEvent: eventName,
        in: .lastSession(appSessionStartAt: appSessionManager.appSession.startAt),
        isPreemptive: isPreemptive
      ),
      "$count_today": storage.coreDataManager.count(
        ofEvent: eventName,
        in: .today,
        isPreemptive: isPreemptive
      ),
      "$first_occurred_at": storage.coreDataManager.getIsoDateOfEventOccurrence(
        withName: eventName,
        position: .first,
        newEventDate: eventCreatedAt
      ),
      "$last_occurred_at": storage.coreDataManager.getIsoDateOfEventOccurrence(
        withName: eventName,
        position: .last,
        newEventDate: eventCreatedAt
      )
    ]*/
  }
}
