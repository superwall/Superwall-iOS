//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/06/2022.
//

import Foundation
import CoreData

class CoreDataManager {
  let coreDataStack: CoreDataStack
  private(set) var backgroundContext: NSManagedObjectContext?

  /// How the manager hears about the app going to the background.
  let lifecycle: AppLifecycle

  /// Only touched on `backgroundContext`'s queue, apart from in `init`.
  var trimState = TrimState()

  init(
    coreDataStack: CoreDataStack = CoreDataStack(),
    lifecycle: AppLifecycle = .live
  ) {
    self.coreDataStack = coreDataStack
    self.lifecycle = lifecycle
    if let persistentContainer = coreDataStack.persistentContainer {
      backgroundContext = persistentContainer.newBackgroundContext()
    }
    observeAppBackground()
    trimSavedPlacements()
  }

  deinit {
    stopObservingAppBackground()
  }

  /// Saves when a placement happened, so audience filters can count it and tell
  /// how long ago it last happened. Its parameters aren't saved: nothing reads
  /// them back, and they're most of a placement's size.
  func savePlacementData(
    _ placementData: PlacementData,
    completion: ((ManagedEventData) -> Void)? = nil
  ) {
    guard let backgroundContext = backgroundContext else {
      return
    }
    if !Self.isSaved(placementNamed: placementData.name) {
      return
    }
    backgroundContext.perform {
      guard let managedEventData = ManagedEventData(
        context: backgroundContext,
        id: placementData.id,
        createdAt: placementData.createdAt,
        name: placementData.name,
        parameters: Data()
      ) else {
        return
      }

      do {
        if backgroundContext.hasChanges {
          try backgroundContext.save()
        }
        completion?(managedEventData)
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
    triggerAudienceOccurrence audienceOccurence: TriggerAudienceOccurrence,
    completion: ((ManagedTriggerRuleOccurrence) -> Void)? = nil
  ) {
    guard let backgroundContext = backgroundContext else {
      return
    }
    backgroundContext.perform {
      guard let managedAudienceOccurrence = ManagedTriggerRuleOccurrence(
        context: backgroundContext,
        createdAt: Date(),
        occurrenceKey: audienceOccurence.key
      ) else {
        return
      }

      do {
        if backgroundContext.hasChanges {
          try backgroundContext.save()
        }
        completion?(managedAudienceOccurrence)
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

  // swiftlint:disable:next function_body_length
  func deleteAllEntities(completion: (() -> Void)? = nil) {
    guard let backgroundContext = backgroundContext else {
      completion?()
      return
    }

    // Check if we're using an in-memory store (batch delete not supported for in-memory)
    let isInMemory = coreDataStack.persistentContainer?.persistentStoreDescriptions
      .contains { $0.type == NSInMemoryStoreType } ?? false

    backgroundContext.performAndWait {
      let appLevelEvents = ["app_install", "app_launch"]
      let excludeAppLevelPredicate = NSPredicate(format: "NOT (name IN %@)", appLevelEvents)

      if isInMemory {
        // Use regular delete for in-memory stores
        let eventDataRequest: NSFetchRequest<ManagedEventData> = ManagedEventData.fetchRequest()
        eventDataRequest.predicate = excludeAppLevelPredicate
        if let eventData = try? backgroundContext.fetch(eventDataRequest) {
          for object in eventData {
            backgroundContext.delete(object)
          }
        }

        let occurrenceRequest: NSFetchRequest<ManagedTriggerRuleOccurrence> =
          ManagedTriggerRuleOccurrence.fetchRequest()
        if let occurrences = try? backgroundContext.fetch(occurrenceRequest) {
          for object in occurrences {
            backgroundContext.delete(object)
          }
        }

        do {
          if backgroundContext.hasChanges {
            try backgroundContext.save()
          }
          completion?()
        } catch {
          Logger.debug(
            logLevel: .error,
            scope: .coreData,
            message: "Could not delete core data.",
            error: error
          )
          completion?()
        }
      } else {
        // Use batch delete for persistent stores (more efficient)
        let eventDataRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
          entityName: ManagedEventData.entityName
        )
        eventDataRequest.predicate = excludeAppLevelPredicate
        let deletePlacementDataRequest = NSBatchDeleteRequest(fetchRequest: eventDataRequest)

        let occurrenceRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
          entityName: ManagedTriggerRuleOccurrence.entityName
        )
        let deleteOccurrenceRequest = NSBatchDeleteRequest(fetchRequest: occurrenceRequest)

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
          completion?()
        }
      }
    }
  }

  func getComputedPropertySincePlacement(
    _ placement: PlacementData?,
    request: ComputedPropertyRequest
  ) async -> Int? {
    if !Self.isSaved(placementNamed: request.placementName) {
      return nil
    }
    var lastEventDate: Date?
    if let placement = placement {
      lastEventDate = placement.name == request.placementName ? placement.createdAt : nil
    }

    guard let createdAt = await coreDataStack.getLastSavedPlacementDate(
      name: request.placementName,
      before: lastEventDate
    ) else {
      return nil
    }
    let components = Calendar.current.dateComponents(
      [request.type.calendarComponent],
      from: createdAt,
      to: Date()
    )
    return request.type.dateComponent(from: components)
  }

  func countAudienceOccurrences(
    for audienceOccurrence: TriggerAudienceOccurrence
  ) async -> Int {
    let fetchRequest = ManagedTriggerRuleOccurrence.fetchRequest()
    fetchRequest.fetchLimit = audienceOccurrence.maxCount

    switch audienceOccurrence.interval {
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
        return audienceOccurrence.maxCount
      }
      fetchRequest.predicate = NSPredicate(
        format: "createdAt >= %@ AND occurrenceKey == %@",
        date as NSDate,
        audienceOccurrence.key
      )

      return await coreDataStack.count(for: fetchRequest)
    case .infinity:
      fetchRequest.predicate = NSPredicate(format: "occurrenceKey == %@", audienceOccurrence.key)
      return await coreDataStack.count(for: fetchRequest)
    }
  }

  func countPlacement(
    _ placementName: String,
    interval: TriggerAudienceOccurrence.Interval
  ) async -> Int {
    switch interval {
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
        return 0
      }
      return await countPlacement(placementName, since: date)
    case .infinity:
      return await countPlacement(placementName, since: nil)
    }
  }

  /// Counts the placements with the given name saved on or after `startDate`,
  /// or all of them when `startDate` is `nil`.
  func countPlacement(
    _ placementName: String,
    since startDate: Date?
  ) async -> Int {
    if !Self.isSaved(placementNamed: placementName) {
      return 0
    }
    let fetchRequest = ManagedEventData.fetchRequest()

    if let startDate = startDate {
      fetchRequest.predicate = NSPredicate(
        format: "createdAt >= %@ AND name == %@",
        startDate as NSDate,
        placementName
      )
    } else {
      fetchRequest.predicate = NSPredicate(format: "name == %@", placementName)
    }

    return await coreDataStack.count(for: fetchRequest)
  }
}
