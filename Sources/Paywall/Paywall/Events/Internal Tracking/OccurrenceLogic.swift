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
    return [
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
    ]
  }
}
