//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/06/2022.
//

import Foundation

protocol Occurrable {
  static func getOccurrence(
    from eventArray: [EventData],
    isInPostfix: Bool
  ) -> Value
  associatedtype Value
}

enum Occurrence {
  enum SinceInstall: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isInPostfix: Bool
    ) -> Value {
      let count = eventArray.count
      if isInPostfix {
        return count
      } else {
        return count + 1
      }
    }

    typealias Value = Int
  }

  enum Last30Days: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isInPostfix: Bool
    ) -> Value {
      guard let thirtyDaysBeforeToday = Calendar.current.date(
        byAdding: .day,
        value: -30,
        to: Date()
      ) else {
        return 0
      }
      let eventsInLast30d = eventArray.filter { $0.createdAt >= thirtyDaysBeforeToday }
      if isInPostfix {
        return eventsInLast30d.count
      } else {
        return eventsInLast30d.count + 1
      }
    }

    typealias Value = Int
  }

  enum Last7Days: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isInPostfix: Bool
    ) -> Value {
      guard let sevenDaysBeforeToday = Calendar.current.date(
        byAdding: .day,
        value: -7,
        to: Date()
      ) else {
        return 0
      }
      let eventsInLast7d = eventArray.filter { $0.createdAt >= sevenDaysBeforeToday }

      if isInPostfix {
        return eventsInLast7d.count
      } else {
        return eventsInLast7d.count + 1
      }
    }

    typealias Value = Int
  }

  enum Last24Hours: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isInPostfix: Bool
    ) -> Value {
      guard let twentyFourHoursAgo = Calendar.current.date(
        byAdding: .hour,
        value: -24,
        to: Date()
      ) else {
        return 0
      }
      let eventsInLast24h = eventArray.filter { $0.createdAt >= twentyFourHoursAgo }

      if isInPostfix {
        return eventsInLast24h.count
      } else {
        return eventsInLast24h.count + 1
      }
    }

    typealias Value = Int
  }

  enum InLatestSession: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isInPostfix: Bool
    ) -> Value {
      let appSessionStart = AppSessionManager.shared.appSession.startAt
      let eventsInAppSession = eventArray.filter { $0.createdAt >= appSessionStart }

      if isInPostfix {
        return eventsInAppSession.count
      } else {
        return eventsInAppSession.count + 1
      }
    }

    typealias Value = Int
  }

  enum Today: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isInPostfix: Bool
    ) -> Value {
      let startOfDay = Calendar.current.startOfDay(for: Date())
      let eventsInAppSession = eventArray.filter { $0.createdAt >= startOfDay }

      if isInPostfix {
        return eventsInAppSession.count
      } else {
        return eventsInAppSession.count + 1
      }
    }

    typealias Value = Int
  }

  enum FirstTime: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isInPostfix: Bool
    ) -> Value {
      let date = eventArray.first?.createdAt ?? Date()
      return date.isoString
    }

    typealias Value = String
  }

  enum LastTime: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isInPostfix: Bool
    ) -> Value {
      if isInPostfix {
        let date = eventArray.last?.createdAt ?? Date()
        return date.isoString
      } else {
        return Date().isoString
      }
    }

    typealias Value = String
  }
}
