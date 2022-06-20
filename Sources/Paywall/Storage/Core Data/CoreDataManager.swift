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
    completion: ((ManagedEvent) -> Void)? = nil
  ) {
    let context = coreDataStack.backgroundContext

    context.perform {
      let data = try? JSONEncoder().encode(eventData.parameters)

      let managedEventData = ManagedEventData(
        context: context,
        id: eventData.id,
        createdAt: eventData.createdAt,
        name: eventData.name,
        parameters: data ?? Data()
      )

      let request = ManagedEvent.fetchRequest()
      request.predicate = NSPredicate(format: "name == %@", eventData.name)

      if let event = self.coreDataStack.fetch(request, context: context).first {
        managedEventData.event = event
        event.addToData(managedEventData)
        self.coreDataStack.saveContext(context)
        completion?(event)
      } else {
        let event = ManagedEvent(
          context: context,
          name: eventData.name,
          data: [managedEventData]
        )
        managedEventData.event = event
        self.coreDataStack.saveContext(context)
        completion?(event)
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
    let fetchRequest = ManagedEvent.fetchRequest()
    let eventData = coreDataStack.fetch(fetchRequest)
    let names = eventData.map { $0.name }
    return names
  }
}
