//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/06/2022.
//

import Foundation
import CoreData

class CoreDataManager {
  private let coreDataStack: CoreDataStack
  private var backgroundContext: NSManagedObjectContext?

  init(coreDataStack: CoreDataStack = CoreDataStack()) {
    self.coreDataStack = coreDataStack
    if let persistentContainer = coreDataStack.persistentContainer {
      backgroundContext = persistentContainer.newBackgroundContext()
    }
  }

  func saveEventData(
    _ eventData: EventData,
    completion: ((ManagedEventData) -> Void)? = nil
  ) {
    guard let backgroundContext = backgroundContext else {
      return
    }
    backgroundContext.perform { [weak self] in
      guard let self = self else {
        return
      }
      let data = try? JSONEncoder().encode(eventData.parameters)
      guard let managedEventData = ManagedEventData(
        context: backgroundContext,
        id: eventData.id,
        createdAt: eventData.createdAt,
        name: eventData.name,
        parameters: data ?? Data()
      ) else {
        return
      }

      self.coreDataStack.saveContext(backgroundContext) {
        completion?(managedEventData)
      }
    }
  }

  func save(
    triggerRuleOccurrence ruleOccurence: TriggerRuleOccurrence,
    completion: ((ManagedTriggerRuleOccurrence) -> Void)? = nil
  ) {
    guard let backgroundContext = backgroundContext else {
      return
    }
    backgroundContext.perform { [weak self] in
      guard let self = self else {
        return
      }
      guard let managedRuleOccurrence = ManagedTriggerRuleOccurrence(
        context: backgroundContext,
        createdAt: Date(),
        occurrenceKey: ruleOccurence.key
      ) else {
        return
      }

      self.coreDataStack.saveContext(backgroundContext) {
        completion?(managedRuleOccurrence)
      }
    }
  }

  func deleteAllEntities() {
    guard let backgroundContext = backgroundContext else {
      return
    }
    let eventDataRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedEventData.entityName
    )
    let deleteEventDataRequest = NSBatchDeleteRequest(fetchRequest: eventDataRequest)

    let occurrenceRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedTriggerRuleOccurrence.entityName
    )
    let deleteOccurrenceRequest = NSBatchDeleteRequest(fetchRequest: occurrenceRequest)

    backgroundContext.performAndWait {
      do {
        try backgroundContext.executeAndMergeChanges(using: deleteEventDataRequest)
        try backgroundContext.executeAndMergeChanges(using: deleteOccurrenceRequest)
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Could not delete core data.",
          error: error
        )
      }
    }
  }

  func getDaysSinceLastEvent(name: String) async -> Int? {
    return await withCheckedContinuation { continuation in
      coreDataStack.getLastSavedEvent(
        name: name) { event in
          guard let event = event else {
            return continuation.resume(returning: nil)
          }
          let createdAt = event.createdAt
          let calendar = Calendar.current
          let currentDate = Date()
          let components = calendar.dateComponents(
            [.day],
            from: createdAt,
            to: currentDate
          )

          continuation.resume(returning: components.day)
        }
    }
  }

  func countTriggerRuleOccurrences(
    for ruleOccurrence: TriggerRuleOccurrence
  ) async -> Int {
    let fetchRequest = ManagedTriggerRuleOccurrence.fetchRequest()
    fetchRequest.fetchLimit = ruleOccurrence.maxCount

    switch ruleOccurrence.interval {
    case .minutes(let minutes):
      guard let date = Calendar.current.date(
        byAdding: .minute,
        value: -minutes,
        to: Date()
      ) else {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Calendar couldn't calculate date by adding \(minutes) minutes and returned nil."
        )
        return .max
      }
      fetchRequest.predicate = NSPredicate(
        format: "createdAt >= %@ AND occurrenceKey == %@",
        date as NSDate,
        ruleOccurrence.key
      )

      return await withCheckedContinuation { continuation in
        coreDataStack.count(for: fetchRequest) { count in
          continuation.resume(returning: count)
        }
      }
    case .infinity:
      fetchRequest.predicate = NSPredicate(format: "occurrenceKey == %@", ruleOccurrence.key)
      return await withCheckedContinuation { continuation in
        coreDataStack.count(for: fetchRequest) { count in
          continuation.resume(returning: count)
        }
      }
    }
  }
}
