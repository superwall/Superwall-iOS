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
        return
      }

      self?.coreDataStack.saveContext(context) {
        completion?(managedRuleOccurrence)
      }
    }
  }

  func deleteAllEntities(completion: (() -> Void)? = nil) {
    let eventDataRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedEventData.entityName
    )
    let deleteEventDataRequest = NSBatchDeleteRequest(fetchRequest: eventDataRequest)

    let occurrenceRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedTriggerRuleOccurrence.entityName
    )
    let deleteOccurrenceRequest = NSBatchDeleteRequest(fetchRequest: occurrenceRequest)

    let container = coreDataStack.persistentContainer
    container.performBackgroundTask { context in
      do {
        try context.executeAndMergeChanges(using: deleteEventDataRequest)
        try context.executeAndMergeChanges(using: deleteOccurrenceRequest)
        completion?()
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

  func countTriggerRuleOccurrences(
    for ruleOccurrence: TriggerRuleOccurrence
  ) -> Int {
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
      return coreDataStack.count(for: fetchRequest)
    case .infinity:
      fetchRequest.predicate = NSPredicate(format: "occurrenceKey == %@", ruleOccurrence.key)
      return coreDataStack.count(for: fetchRequest)
    }
  }
}
