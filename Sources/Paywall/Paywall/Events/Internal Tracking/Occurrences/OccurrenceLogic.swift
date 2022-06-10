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
    isPreemptive: Bool
  ) -> [String: Any] {
    return [
      "$count_since_install": calculate(
        Occurrence.SinceInstall.self,
        of: eventName,
        isPreemptive: isPreemptive
      ),
      "$count_30d": calculate(
        Occurrence.Last30Days.self,
        of: eventName,
        isPreemptive: isPreemptive
      ),
      "$count_7d": calculate(
        Occurrence.Last7Days.self,
        of: eventName,
        isPreemptive: isPreemptive
      ),
      "$count_24h": calculate(
        Occurrence.Last24Hours.self,
        of: eventName,
        isPreemptive: isPreemptive
      ),
      "$count_session": calculate(
        Occurrence.InLatestSession.self,
        of: eventName,
        isPreemptive: isPreemptive
      ),
      "$count_today": calculate(
        Occurrence.Today.self,
        of: eventName,
        isPreemptive: isPreemptive
      ),
      "$first_occurred_at": calculate(
        Occurrence.FirstTime.self,
        of: eventName,
        isPreemptive: isPreemptive
      ),
      "$last_occurred_at": calculate(
        Occurrence.LastTime.self,
        of: eventName,
        isPreemptive: isPreemptive
      )
    ]
  }

  static func calculate<T: Occurrable>(
    _ type: T.Type,
    of eventName: String,
    isPreemptive: Bool
  ) -> T.Value {
    let triggeredEvents = Storage.shared.getTriggeredEvents()
    let eventArray = triggeredEvents[eventName] ?? []
    return type.getOccurrence(
      from: eventArray,
      isPreemptive: isPreemptive
    )
  }
}
