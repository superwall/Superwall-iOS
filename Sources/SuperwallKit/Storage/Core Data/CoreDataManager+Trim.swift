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

  /// Saved as `true` in a store's metadata while it has freed space that
  /// hasn't been given back to the device yet.
  static let needsSpaceReclaimKey = "SWKSavedPlacementsNeedSpaceReclaim"

  /// How many placements one step of the trim deletes or empties.
  static let trimBatchSize = 500

  /// Deletes the loading placements and empties the parameters a store
  /// already holds. Runs once per store. The space this frees is given back
  /// to the device the next time the app goes to the background.
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
      let metadata = coordinator.metadata(for: store)
      let trimmedVersion = metadata[Self.savedPlacementsTrimVersionKey] as? Int
      if (trimmedVersion ?? 0) >= Self.savedPlacementsTrimVersion {
        // If it was trimmed in an earlier launch that ended before the space was
        // given back, that's still to come. Otherwise there's nothing to wait for.
        if metadata[Self.needsSpaceReclaimKey] as? Bool != true {
          self.stopObservingAppBackground()
        }
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

      if let coordinator = context.persistentStoreCoordinator {
        var metadata = coordinator.metadata(for: store)
        metadata[Self.savedPlacementsTrimVersionKey] = Self.savedPlacementsTrimVersion
        metadata[Self.needsSpaceReclaimKey] = true
        coordinator.setMetadata(metadata, for: store)
        try context.save()
        if isAppInBackground {
          // The app went to the background while the trim was running.
          reclaimSpaceIfNeeded(in: context, store: store)
        }
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

  /// Giving space back rewrites the whole store in one go, which takes longer
  /// the more placements it keeps and can't be split into steps. So it waits
  /// until the app is in the background, where nothing is likely to be saving
  /// or resetting.
  ///
  /// Starts following the app from `init`, so that going to the background
  /// while the trim is still running isn't missed.
  func observeAppBackground() {
    guard
      let backgroundContext = backgroundContext,
      let coordinator = coreDataStack.persistentContainer?.persistentStoreCoordinator,
      let store = coordinator.persistentStores.first,
      store.type == NSSQLiteStoreType
    else {
      return
    }
    appBackgroundObservers = [
      notificationCenter.addObserver(
        forName: SystemInfo.applicationDidEnterBackgroundNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        backgroundContext.perform {
          self?.isAppInBackground = true
          self?.reclaimSpaceIfNeeded(in: backgroundContext, store: store)
        }
      },
      notificationCenter.addObserver(
        forName: SystemInfo.applicationWillEnterForegroundNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        backgroundContext.perform {
          self?.isAppInBackground = false
        }
      }
    ]
  }

  /// Must be called on the context's queue, or when nothing else can reach
  /// the manager.
  func stopObservingAppBackground() {
    for observer in appBackgroundObservers {
      notificationCenter.removeObserver(observer)
    }
    appBackgroundObservers = []
  }

  /// Gives the space freed by the trim back to the device, if that's still to
  /// be done. Must be called on `context`'s queue.
  private func reclaimSpaceIfNeeded(in context: NSManagedObjectContext, store: NSPersistentStore) {
    guard
      let coordinator = context.persistentStoreCoordinator,
      let storeUrl = store.url
    else {
      return
    }
    var metadata = coordinator.metadata(for: store)
    if metadata[Self.needsSpaceReclaimKey] as? Bool != true {
      return
    }
    do {
      try Self.reclaimFreeSpace(inStoreAt: storeUrl)
      metadata[Self.needsSpaceReclaimKey] = false
      coordinator.setMetadata(metadata, for: store)
      try context.save()
      stopObservingAppBackground()
    } catch {
      // Still marked as needed, so it's tried again the next time the app
      // goes to the background.
      Logger.debug(
        logLevel: .error,
        scope: .coreData,
        message: "Could not give freed space back.",
        error: error
      )
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
