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
    isPostfix: Bool
  ) -> Value
  associatedtype Value
}

enum Occurrence {
  enum SinceInstall: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isPostfix: Bool
    ) -> Value {
      let count = eventArray.count
      if isPostfix {
        return count + 1
      } else {
        return count
      }
    }

    typealias Value = Int
  }

  enum Last30Days: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isPostfix: Bool
    ) -> Value {
      guard let thirtyDaysBeforeToday = Calendar.current.date(
        byAdding: .day,
        value: -30,
        to: Date()
      ) else {
        return 0
      }
      let eventsInLast30d = eventArray.filter { $0.createdAt >= thirtyDaysBeforeToday }
      if isPostfix {
        return eventsInLast30d.count + 1
      } else {
        return eventsInLast30d.count
      }
    }

    typealias Value = Int
  }

  enum Last7Days: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isPostfix: Bool
    ) -> Value {
      guard let sevenDaysBeforeToday = Calendar.current.date(
        byAdding: .day,
        value: -7,
        to: Date()
      ) else {
        return 0
      }
      let eventsInLast7d = eventArray.filter { $0.createdAt >= sevenDaysBeforeToday }

      if isPostfix {
        return eventsInLast7d.count + 1
      } else {
        return eventsInLast7d.count
      }
    }

    typealias Value = Int
  }

  enum Last24Hours: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isPostfix: Bool
    ) -> Value {
      guard let twentyFourHoursAgo = Calendar.current.date(
        byAdding: .hour,
        value: -24,
        to: Date()
      ) else {
        return 0
      }
      let eventsInLast24h = eventArray.filter { $0.createdAt >= twentyFourHoursAgo }

      if isPostfix {
        return eventsInLast24h.count + 1
      } else {
        return eventsInLast24h.count
      }
    }

    typealias Value = Int
  }

  enum InLatestSession: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isPostfix: Bool
    ) -> Value {
      let appSessionStart = AppSessionManager.shared.appSession.startAt
      let eventsInAppSession = eventArray.filter { $0.createdAt >= appSessionStart }

      if isPostfix {
        return eventsInAppSession.count + 1
      } else {
        return eventsInAppSession.count
      }
    }

    typealias Value = Int
  }

  enum Today: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isPostfix: Bool
    ) -> Value {
      let startOfDay = Calendar.current.startOfDay(for: Date())
      let eventsInAppSession = eventArray.filter { $0.createdAt >= startOfDay }

      if isPostfix {
        return eventsInAppSession.count + 1
      } else {
        return eventsInAppSession.count
      }
    }

    typealias Value = Int
  }

  enum FirstTime: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isPostfix: Bool
    ) -> Value {
      return eventArray.first?.createdAt ?? Date()
    }

    typealias Value = Date
  }

  enum LastTime: Occurrable {
    static func getOccurrence(
      from eventArray: [EventData],
      isPostfix: Bool
    ) -> Value {
      if isPostfix {
        return Date()
      } else {
        return eventArray.last?.createdAt ?? Date()
      }
    }

    typealias Value = Date
  }
}
