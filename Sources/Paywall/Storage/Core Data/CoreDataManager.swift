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

    // TODO: THIS CAUSES A CONFLICT. NEED TO ONLY ADD FIRST TIME EVENT ONCE.
    container.performBackgroundTask { context in
      let data = try? JSONEncoder().encode(eventData.parameters)

      let managedEventData = ManagedEventData(
        context: context,
        id: eventData.id,
        createdAt: eventData.createdAt,
        name: eventData.name,
        parameters: data ?? Data()
      )
      print("**** SAVE", eventData.name)
      self.coreDataStack.saveContext(context) {
        print("**** SAVED", eventData.name)
        completion?(managedEventData)
      }
    }
  }

  func countSinceInstall(
    ofEvent eventName: String,
    isPreemptive: Bool
  ) -> Int {
    let fetchRequest = ManagedEventData.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name == %@", eventName)
    let count = coreDataStack.count(for: fetchRequest)
    return isPreemptive ? count + 1 : count
  }

  func countSinceInstall(
    ofEvent eventName: String,
    isPreemptive: Bool,
    completion: @escaping (Int) -> Void
  ) {
    let fetchRequest = ManagedEventData.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name == %@", eventName)
    coreDataStack.count(for: fetchRequest) { count in
      let count = isPreemptive ? count + 1 : count
      completion(count)
    }
  }

  func count(
    ofEvent eventName: String,
    in since: SinceOption,
    isPreemptive: Bool
  ) -> Int {
    guard let date = since.date else {
      return 0
    }
    let fetchRequest = ManagedEventData.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "createdAt >= %@ AND name == %@", date, eventName)
    fetchRequest.resultType = .countResultType

    let count = coreDataStack.count(for: fetchRequest)
    return isPreemptive ? count + 1 : count
  }

  func count(
    ofEvent eventName: String,
    in since: SinceOption,
    isPreemptive: Bool,
    completion: @escaping (Int) -> Void
  ) {
    guard let date = since.date else {
      return completion(0)
    }
    let fetchRequest = ManagedEventData.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "createdAt >= %@ AND name == %@", date, eventName)
    fetchRequest.resultType = .countResultType

    coreDataStack.count(for: fetchRequest) { count in
      let count = isPreemptive ? count + 1 : count
      completion(count)
    }
  }

  func getIsoDateOfEventOccurrence(
    withName name: Paywall.EventName.RawValue,
    position: Position,
    newEventDate: Date? = nil
  ) -> String {
    let fetchRequest = ManagedEventData.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name == %@", name)
    let ascending = position == .first ? true : false
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: ascending)]
    fetchRequest.fetchLimit = 1

    // If first/last occurrence then return date. If paywall, then return optional date
    if let eventData = coreDataStack.fetch(fetchRequest).first {
      return eventData.createdAt.isoString
    } else {
      return newEventDate?.isoString ?? ""
    }
  }

  func getIsoDateOfEventOccurrence(
    withName name: Paywall.EventName.RawValue,
    position: Position,
    newEventDate: Date? = nil,
    completion: @escaping (String) -> Void
  ) {
    let fetchRequest = ManagedEventData.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name == %@", name)
    let ascending = position == .first ? true : false
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: ascending)]
    fetchRequest.propertiesToFetch = ["createdAt"]
    fetchRequest.fetchLimit = 1

    // If first/last occurrence then return date. If paywall, then return optional date
    coreDataStack.fetch(fetchRequest) { items in
      if let eventData = items.first {
        completion(eventData.createdAt.isoString)
      } else {
        completion(newEventDate?.isoString ?? "")
      }
    }
  }

  func getLastPaywallOpen() -> Date? {
    let eventName = Paywall.EventName.paywallOpen.rawValue
    let fetchRequest = makeEventDataFetchRequest(
      name: eventName,
      sortAscending: false
    )

    // If first/last occurrence then return date. If paywall, then return optional date
    if let eventData = coreDataStack.fetch(fetchRequest).first {
      return eventData.createdAt
    } else {
      return nil
    }
  }

  private func makeEventDataFetchRequest(
    name: String,
    sortAscending: Bool
  ) -> NSFetchRequest<ManagedEventData> {
    let fetchRequest = ManagedEventData.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "name == %@", name)
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: sortAscending)]
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }

  func getAllEventNames() -> [String] {
    let request = NSFetchRequest<NSDictionary>(entityName: "EventData")

    let column = "name"
    request.propertiesToFetch = [column]
    request.returnsDistinctResults = true
    request.resultType = .dictionaryResultType

    guard let result = coreDataStack.fetch(request) as? [[String: String]] else {
      return []
    }
    return result.compactMap { $0[column] }
  }
}
