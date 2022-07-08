//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/06/2022.
//

import Foundation
import CoreData

final class CoreDataManager {
  enum SinceOption {
    case thirtyDays
    case sevenDays
    case twentyFourHours
    case lastSession(appSessionStartAt: Date)
    case today

    var date: NSDate? {
      switch self {
      case .thirtyDays:
        guard let thirtyDaysBeforeToday = Calendar.current.date(
          byAdding: .day,
          value: -30,
          to: Date()
        ) else {
          return nil
        }
        return thirtyDaysBeforeToday as NSDate
      case .sevenDays:
        guard let sevenDaysBeforeToday = Calendar.current.date(
          byAdding: .day,
          value: -7,
          to: Date()
        ) else {
          return nil
        }
        return sevenDaysBeforeToday as NSDate
      case .twentyFourHours:
        guard let twentyFourHoursAgo = Calendar.current.date(
          byAdding: .hour,
          value: -24,
          to: Date()
        ) else {
          return nil
        }
        return twentyFourHoursAgo as NSDate
      case .lastSession(let sessionStartAt):
        return sessionStartAt as NSDate
      case .today:
        return Calendar.current.startOfDay(for: Date()) as NSDate
      }
    }
  }
  enum Position {
    case first, last
  }
  private let coreDataStack: CoreDataStack

  init(coreDataStack: CoreDataStack = CoreDataStack()) {
    self.coreDataStack = coreDataStack
  }

  func saveEventData(
    _ eventData: EventData,
    completion: ((ManagedEventData) -> Void)? = nil
  ) {
    let container = coreDataStack.persistentContainer

    container.performBackgroundTask { [weak self] context in
      let data = try? JSONEncoder().encode(eventData.parameters)
      guard let managedEventData = ManagedEventData(
        context: context,
        id: eventData.id,
        createdAt: eventData.createdAt,
        name: eventData.name,
        parameters: data ?? Data()
      ) else {
        Logger.debug(
          logLevel: .debug,
          scope: .paywallCore,
          message: "Failed to create managed event data for event \(eventData.name)"
        )
        return
      }

      self?.coreDataStack.saveContext(context) {
        completion?(managedEventData)
      }
    }
  }

  func save(
    triggerRuleOccurrence ruleOccurence: TriggerRuleOccurrence,
    completion: ((ManagedTriggerRuleOccurrence) -> Void)? = nil
  ) {
    let container = coreDataStack.persistentContainer

    container.performBackgroundTask { [weak self] context in
      guard let managedRuleOccurrence = ManagedTriggerRuleOccurrence(
        context: context,
        createdAt: Date(),
        occurrenceKey: ruleOccurence.key
      ) else {
        Logger.debug(
          logLevel: .debug,
          scope: .paywallCore,
          message: "Failed to create managed trigger rule occurrence for key: \(ruleOccurence.key)"
        )
        return
      }

      self?.coreDataStack.saveContext(context) {
        completion?(managedRuleOccurrence)
      }
    }
  }

  func countTriggerRuleOccurrences(
    for ruleOccurrence: TriggerRuleOccurrence
  ) -> Int {
    let fetchRequest = ManagedTriggerRuleOccurrence.fetchRequest()
    fetchRequest.fetchLimit = ruleOccurrence.maxCount

    switch ruleOccurrence.interval {
    case .minutes(let minutes):
      let date = Calendar.current.date(
        byAdding: .minute,
        value: -minutes,
        to: Date()
      ) ?? Date()
      fetchRequest.predicate = NSPredicate(
        format: "createdAt >= %@ AND occurrenceKey == %@",
        date as NSDate,
        ruleOccurrence.key
      )
      return coreDataStack.count(for: fetchRequest)
    case .infinity:
      fetchRequest.predicate = NSPredicate(format: "occurrenceKey == %@", ruleOccurrence.key)
      return coreDataStack.count(for: fetchRequest)
    }
  }
}
