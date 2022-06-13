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
    isInPostfix: Bool,
    storage: Storage = Storage.shared
  ) -> [String: Any] {
    return [
      "$count_since_install": calculate(
        Occurrence.SinceInstall.self,
        of: eventName,
        isInPostfix: isInPostfix,
        storage: storage
      ),
      "$count_30d": calculate(
        Occurrence.Last30Days.self,
        of: eventName,
        isInPostfix: isInPostfix,
        storage: storage
      ),
      "$count_7d": calculate(
        Occurrence.Last7Days.self,
        of: eventName,
        isInPostfix: isInPostfix,
        storage: storage
      ),
      "$count_24h": calculate(
        Occurrence.Last24Hours.self,
        of: eventName,
        isInPostfix: isInPostfix,
        storage: storage
      ),
      "$count_session": calculate(
        Occurrence.InLatestSession.self,
        of: eventName,
        isInPostfix: isInPostfix,
        storage: storage
      ),
      "$count_today": calculate(
        Occurrence.Today.self,
        of: eventName,
        isInPostfix: isInPostfix,
        storage: storage
      ),
      "$first_occurred_at": calculate(
        Occurrence.FirstTime.self,
        of: eventName,
        isInPostfix: isInPostfix,
        storage: storage
      ),
      "$last_occurred_at": calculate(
        Occurrence.LastTime.self,
        of: eventName,
        isInPostfix: isInPostfix,
        storage: storage
      )
    ]
  }

  static func calculate<T: Occurrable>(
    _ type: T.Type,
    of eventName: String,
    isInPostfix: Bool,
    storage: Storage
  ) -> T.Value {
    let triggeredEvents = storage.getTriggeredEvents()
    let eventArray = triggeredEvents[eventName] ?? []
    return type.getOccurrence(
      from: eventArray,
      isInPostfix: isInPostfix
    )
  }
}
