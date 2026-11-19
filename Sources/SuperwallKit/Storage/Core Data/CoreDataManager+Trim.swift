//
//  CoreDataManager+Trim.swift
//  SuperwallKit
//

import Foundation
import CoreData

extension CoreDataManager {
  /// Preloading and loading placements aren't saved or counted. They follow
  /// what the SDK does, not what the user does: the loading ones fire for every
  /// paywall on every preload, the same as when a paywall is shown.
  static let unsavedPlacementNames: Set<String> = {
    let placements: [SuperwallEventObjc] = [
      .paywallPreloadStart,
      .paywallPreloadComplete,
      .paywallResponseLoadStart,
      .paywallResponseLoadNotFound,
      .paywallResponseLoadFail,
      .paywallResponseLoadComplete,
      .paywallProductsLoadStart,
      .paywallProductsLoadFail,
      .paywallProductsLoadRetry,
      .paywallProductsLoadMissingProducts,
      .paywallProductsLoadComplete,
      .paywallWebviewLoadStart,
      .paywallWebviewLoadFail,
      .paywallWebviewLoadComplete,
      .paywallWebviewLoadTimeout,
      .paywallWebviewLoadFallback,
      .paywallWebviewProcessTerminated,
      .shimmerViewStart,
      .shimmerViewComplete
    ]
    return Set(placements.map { $0.description })
  }()

  static func isSaved(placementNamed name: String) -> Bool {
    return !unsavedPlacementNames.contains(name)
  }

  /// Saved in a store's metadata once `trimSavedPlacements` has finished with
  /// it. Raise it to clean every store again, such as after adding to
  /// `unsavedPlacementNames`.
  static let savedPlacementsTrimVersion = 1
  static let savedPlacementsTrimVersionKey = "SWKSavedPlacementsTrimVersion"

  /// How many placements one step of the trim deletes or empties.
  static let trimBatchSize = 500

  /// Shrinks a store that already holds loading placements and parameters,
  /// then gives the freed space back to the device. Runs once per store.
  ///
  /// It works in small steps, each queued behind whatever is already waiting
  /// on the context, so saving a placement or resetting never waits for more
  /// than one step.
  func trimSavedPlacements(completion: (() -> Void)? = nil) {
    guard
      let backgroundContext = backgroundContext,
      let coordinator = coreDataStack.persistentContainer?.persistentStoreCoordinator,
      let store = coordinator.persistentStores.first,
      store.type == NSSQLiteStoreType
    else {
      completion?()
      return
    }

    backgroundContext.perform {
      if self.trimCompletions != nil {
        // A trim is already running. Hear about it finishing instead.
        if let completion = completion {
          self.trimCompletions?.append(completion)
        }
        return
      }
      let trimmedVersion = coordinator.metadata(for: store)[Self.savedPlacementsTrimVersionKey] as? Int
      if (trimmedVersion ?? 0) >= Self.savedPlacementsTrimVersion {
        completion?()
        return
      }
      self.trimCompletions = [completion].compactMap { $0 }
      self.runTrimStep(emptying: [], in: backgroundContext, store: store)
    }
  }

  /// Runs one step, then queues the next. Must be called on `context`'s queue.
  ///
  /// - Parameter placementIds: Placements already found to have parameters,
  ///   which are emptied a batch at a time.
  private func runTrimStep(
    emptying placementIds: [NSManagedObjectID],
    in context: NSManagedObjectContext,
    store: NSPersistentStore
  ) {
    do {
      var remainingIds = placementIds
      let isFinished: Bool

      if !remainingIds.isEmpty {
        let batch = Array(remainingIds.prefix(Self.trimBatchSize))
        remainingIds.removeFirst(batch.count)
        try Self.emptyParameters(ofPlacementsWithIds: batch, in: context)
        isFinished = false
      } else if try Self.deleteUnsavedPlacements(upTo: Self.trimBatchSize, in: context) > 0 {
        isFinished = false
      } else {
        remainingIds = try Self.idsOfPlacementsWithParameters(in: context)
        isFinished = remainingIds.isEmpty
      }

      if !isFinished {
        context.perform {
          self.runTrimStep(emptying: remainingIds, in: context, store: store)
        }
        return
      }

      if let storeUrl = store.url {
        try Self.reclaimFreeSpace(inStoreAt: storeUrl)
      }
      if let coordinator = context.persistentStoreCoordinator {
        var metadata = coordinator.metadata(for: store)
        metadata[Self.savedPlacementsTrimVersionKey] = Self.savedPlacementsTrimVersion
        coordinator.setMetadata(metadata, for: store)
        try context.save()
      }
    } catch {
      // The version isn't saved, so the trim carries on at the next launch.
      Logger.debug(
        logLevel: .error,
        scope: .coreData,
        message: "Could not trim saved placements.",
        error: error
      )
    }

    let completions = trimCompletions ?? []
    trimCompletions = nil
    for completion in completions {
      completion()
    }
  }

  /// - Returns: How many placements were deleted.
  private static func deleteUnsavedPlacements(
    upTo limit: Int,
    in context: NSManagedObjectContext
  ) throws -> Int {
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
      entityName: ManagedEventData.entityName
    )
    fetchRequest.predicate = NSPredicate(format: "name IN %@", unsavedPlacementNames)
    fetchRequest.fetchLimit = limit
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    deleteRequest.resultType = .resultTypeCount
    let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
    return result?.result as? Int ?? 0
  }

  /// The placements that still have parameters, up to a number that keeps the
  /// list small in memory. The trim asks again once it has emptied these.
  private static func idsOfPlacementsWithParameters(
    in context: NSManagedObjectContext
  ) throws -> [NSManagedObjectID] {
    let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: ManagedEventData.entityName)
    fetchRequest.resultType = .managedObjectIDResultType
    fetchRequest.predicate = NSPredicate(format: "parameters != %@", Data() as NSData)
    fetchRequest.fetchLimit = 20_000
    return try context.fetch(fetchRequest)
  }

  private static func emptyParameters(
    ofPlacementsWithIds placementIds: [NSManagedObjectID],
    in context: NSManagedObjectContext
  ) throws {
    let updateRequest = NSBatchUpdateRequest(entityName: ManagedEventData.entityName)
    updateRequest.predicate = NSPredicate(format: "SELF IN %@", placementIds)
    updateRequest.propertiesToUpdate = [
      "parameters": NSExpression(forConstantValue: Data())
    ]
    try context.execute(updateRequest)
  }

  /// SQLite keeps the pages freed by a delete inside the file. Opening the
  /// store with the vacuum option rewrites the file without them. The rewrite
  /// lands in the -wal file, so a second open moves it into the main file,
  /// which is what shortens it.
  private static func reclaimFreeSpace(inStoreAt url: URL) throws {
    let optionsForEachOpen: [[AnyHashable: Any]] = [
      [NSSQLiteManualVacuumOption: true],
      [NSSQLitePragmasOption: ["wal_checkpoint": "TRUNCATE"]]
    ]
    for options in optionsForEachOpen {
      let coordinator = NSPersistentStoreCoordinator(
        managedObjectModel: CoreDataStack.managedObject
      )
      let store = try coordinator.addPersistentStore(
        ofType: NSSQLiteStoreType,
        configurationName: nil,
        at: url,
        options: options
      )
      try coordinator.remove(store)
    }
  }
}
