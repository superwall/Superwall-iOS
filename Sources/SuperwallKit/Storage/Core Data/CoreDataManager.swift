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

  func savePlacementData(
    _ eventData: PlacementData,
    completion: ((ManagedPlacementData) -> Void)? = nil
  ) {
    guard let backgroundContext = backgroundContext else {
      return
    }
    backgroundContext.perform {
      let data = try? JSONEncoder().encode(eventData.parameters)
      guard let managedPlacementData = ManagedPlacementData(
        context: backgroundContext,
        id: eventData.id,
        createdAt: eventData.createdAt,
        name: eventData.name,
        parameters: data ?? Data()
      ) else {
        return
      }

      do {
        if backgroundContext.hasChanges {
          try backgroundContext.save()
        }
        completion?(managedPlacementData)
      } catch let error as NSError {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Error saving to Core Data.",
          info: error.userInfo,
          error: error
        )
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
    backgroundContext.perform {
      guard let managedRuleOccurrence = ManagedTriggerRuleOccurrence(
        context: backgroundContext,
        createdAt: Date(),
        occurrenceKey: ruleOccurence.key
      ) else {
        return
      }

      do {
        if backgroundContext.hasChanges {
          try backgroundContext.save()
        }
        completion?(managedRuleOccurrence)
      } catch let error as NSError {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Error saving to Core Data.",
          info: error.userInfo,
          error: error
        )
      }
    }
  }

  func deleteAllEntities(completion: (() -> Void)? = nil) {
    guard let backgroundContext = backgroundContext else {
      return
    }
    let eventDataRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedPlacementData.entityName
    )
    let deletePlacementDataRequest = NSBatchDeleteRequest(fetchRequest: eventDataRequest)

    let occurrenceRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedTriggerRuleOccurrence.entityName
    )
    let deleteOccurrenceRequest = NSBatchDeleteRequest(fetchRequest: occurrenceRequest)

    backgroundContext.performAndWait {
      do {
        try backgroundContext.executeAndMergeChanges(using: deletePlacementDataRequest)
        try backgroundContext.executeAndMergeChanges(using: deleteOccurrenceRequest)
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

  func getComputedPropertySincePlacement(
    _ event: PlacementData?,
    request: ComputedPropertyRequest
  ) async -> Int? {
    var lastEventDate: Date?
    if let event = event {
      lastEventDate = event.name == request.placementName ? event.createdAt : nil
    }

    return await withCheckedContinuation { continuation in
      coreDataStack.getLastSavedEvent(
        name: request.placementName,
        before: lastEventDate
      ) { event in
        guard let event = event else {
          return continuation.resume(returning: nil)
        }
        let createdAt = event.createdAt
        let calendar = Calendar.current
        let currentDate = Date()
        let components = calendar.dateComponents(
          [request.type.calendarComponent],
          from: createdAt,
          to: currentDate
        )

        continuation.resume(returning: request.type.dateComponent(from: components))
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
        // Return maxCount so that it won't fire the trigger.
        return ruleOccurrence.maxCount
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
