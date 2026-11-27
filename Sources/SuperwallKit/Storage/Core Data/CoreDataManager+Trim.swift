//
//  CoreDataManager+Trim.swift
//  SuperwallKit
//

import Foundation
import CoreData

extension CoreDataManager {
  /// How the manager hears about the app going to the background, and keeps
  /// it running once it's there. Tests pass their own.
  struct AppLifecycle {
    let notificationCenter: NotificationCenter

    /// Runs `work` somewhere it may block, keeping the app awake until it
    /// returns where the system would otherwise suspend it. Doesn't run it at
    /// all if the system won't allow that.
    let runWithBackgroundTime: (_ work: @escaping () -> Void) -> Void

    static let live = AppLifecycle(notificationCenter: .default) { work in
      #if os(macOS)
      DispatchQueue.global(qos: .utility).async(execute: work)
      #else
      ProcessInfo.processInfo.performExpiringActivity(
        withReason: "Superwall is tidying its database"
      ) { expired in
        if expired {
          return
        }
        work()
      }
      #endif
    }
  }

  struct TrimState {
    /// Called once the trim that's running has finished. `nil` when none is
    /// running.
    var completions: [() -> Void]?

    /// Follow the app going to and from the background while a store still
    /// has space to give back.
    var appBackgroundObservers: [NSObjectProtocol] = []

    var isAppInBackground = false
  }

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

  /// Saved in a store's metadata: how many more times to try giving its freed
  /// space back to the device. Zero once that's done or given up on.
  static let spaceReclaimAttemptsLeftKey = "SWKSavedPlacementsSpaceReclaimAttemptsLeft"

  /// A try fails when something else is using the store at that moment. A few
  /// tries on different days covers that without ever trying forever.
  static let spaceReclaimAttempts = 3

  /// How many placements one step of the trim deletes or empties.
  static let trimBatchSize = 500

  /// How many placements with parameters the trim looks up at a time.
  static let parametersSearchLimit = 20_000

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
      if self.trimState.completions != nil {
        // A trim is already running. Hear about it finishing instead.
        if let completion = completion {
          self.trimState.completions?.append(completion)
        }
        return
      }
      let metadata = coordinator.metadata(for: store)
      let trimmedVersion = metadata[Self.savedPlacementsTrimVersionKey] as? Int
      if (trimmedVersion ?? 0) >= Self.savedPlacementsTrimVersion {
        // If it was trimmed in an earlier launch that ended before the space was
        // given back, that's still to come. Otherwise there's nothing to wait for.
        if (metadata[Self.spaceReclaimAttemptsLeftKey] as? Int ?? 0) <= 0 {
          self.stopObservingAppBackground()
        }
        completion?()
        return
      }
      self.trimState.completions = [completion].compactMap { $0 }
      self.runTrimStep(emptying: [], searchedUpTo: nil, in: backgroundContext, store: store)
    }
  }

  /// Runs one step, then queues the next. Must be called on `context`'s queue.
  ///
  /// - Parameters:
  ///   - placementIds: Placements already found to have parameters, which are
  ///     emptied a batch at a time.
  ///   - lastSearchedId: Where the search for parameters has got to.
  private func runTrimStep(
    emptying placementIds: [NSManagedObjectID],
    searchedUpTo lastSearchedId: NSManagedObjectID?,
    in context: NSManagedObjectContext,
    store: NSPersistentStore
  ) {
    do {
      var remainingIds = placementIds
      var lastSearchedId = lastSearchedId
      let isFinished: Bool

      if !remainingIds.isEmpty {
        let batch = Array(remainingIds.prefix(Self.trimBatchSize))
        remainingIds.removeFirst(batch.count)
        try Self.emptyParameters(ofPlacementsWithIds: batch, in: context)
        isFinished = false
      } else if try Self.deleteUnsavedPlacements(upTo: Self.trimBatchSize, in: context) > 0 {
        isFinished = false
      } else {
        remainingIds = try Self.idsOfPlacementsWithParameters(
          after: lastSearchedId,
          upTo: Self.parametersSearchLimit,
          in: context
        )
        lastSearchedId = remainingIds.last ?? lastSearchedId
        isFinished = remainingIds.isEmpty
      }

      if !isFinished {
        context.perform {
          self.runTrimStep(emptying: remainingIds, searchedUpTo: lastSearchedId, in: context, store: store)
        }
        return
      }

      if let coordinator = context.persistentStoreCoordinator {
        var metadata = coordinator.metadata(for: store)
        metadata[Self.savedPlacementsTrimVersionKey] = Self.savedPlacementsTrimVersion
        metadata[Self.spaceReclaimAttemptsLeftKey] = Self.spaceReclaimAttempts
        coordinator.setMetadata(metadata, for: store)
        try context.save()
        if trimState.isAppInBackground {
          // The app went to the background while the trim was running.
          reclaimSpaceWithBackgroundTime(in: context, store: store)
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

    let completions = trimState.completions ?? []
    trimState.completions = nil
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
    trimState.appBackgroundObservers = [
      lifecycle.notificationCenter.addObserver(
        forName: SystemInfo.applicationDidEnterBackgroundNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        backgroundContext.perform {
          self?.trimState.isAppInBackground = true
        }
        self?.reclaimSpaceWithBackgroundTime(in: backgroundContext, store: store)
      },
      lifecycle.notificationCenter.addObserver(
        forName: SystemInfo.applicationWillEnterForegroundNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        backgroundContext.perform {
          self?.trimState.isAppInBackground = false
        }
      }
    ]
  }

  /// Must be called on the context's queue, or when nothing else can reach
  /// the manager.
  func stopObservingAppBackground() {
    for observer in trimState.appBackgroundObservers {
      lifecycle.notificationCenter.removeObserver(observer)
    }
    trimState.appBackgroundObservers = []
  }

  /// The system suspends an app soon after it goes to the background, so this
  /// asks it to hold off until the space has been given back.
  private func reclaimSpaceWithBackgroundTime(
    in context: NSManagedObjectContext,
    store: NSPersistentStore
  ) {
    lifecycle.runWithBackgroundTime { [weak self] in
      context.performAndWait {
        // This waits for its turn, and the app may have come back by then.
        if self?.trimState.isAppInBackground != true {
          return
        }
        self?.reclaimSpaceIfNeeded(in: context, store: store)
      }
    }
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
    var attemptsLeft = metadata[Self.spaceReclaimAttemptsLeftKey] as? Int ?? 0
    if attemptsLeft <= 0 {
      return
    }

    do {
      try Self.reclaimFreeSpace(inStoreAt: storeUrl)
      // Done once the rewrite has been moved into the main file. That doesn't
      // mean the file got smaller: a new install has nothing to give back.
      let isDone = Self.isWriteAheadLogEmpty(forStoreAt: storeUrl)
      attemptsLeft = isDone ? 0 : attemptsLeft - 1
    } catch {
      attemptsLeft -= 1
      Logger.debug(
        logLevel: .error,
        scope: .coreData,
        message: "Could not give freed space back.",
        error: error
      )
    }

    metadata[Self.spaceReclaimAttemptsLeftKey] = attemptsLeft
    coordinator.setMetadata(metadata, for: store)
    try? context.save()
    if attemptsLeft <= 0 {
      stopObservingAppBackground()
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

  /// The next placements that still have parameters, in the order the store
  /// keeps them, up to a number that keeps the list small in memory. The
  /// search starts after `lastSearchedId`, the last one an earlier call
  /// returned, so the store goes straight there instead of reading every
  /// placement before it again.
  static func idsOfPlacementsWithParameters(
    after lastSearchedId: NSManagedObjectID?,
    upTo limit: Int,
    in context: NSManagedObjectContext
  ) throws -> [NSManagedObjectID] {
    let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: ManagedEventData.entityName)
    fetchRequest.resultType = .managedObjectIDResultType
    var predicates = [NSPredicate(format: "parameters != %@", Data() as NSData)]
    if let lastSearchedId {
      predicates.append(NSPredicate(format: "SELF > %@", lastSearchedId))
    }
    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "self", ascending: true)]
    fetchRequest.fetchLimit = limit
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
  ///
  /// The second open does nothing, without an error, if something is reading
  /// the store. Left alone it waits half a minute for the reader first, so
  /// both opens give up after a second.
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
        options: options.merging([NSPersistentStoreTimeoutOption: 1]) { option, _ in option }
      )
      try coordinator.remove(store)
    }
  }

  /// Whether everything in the store's -wal file has been moved into its main
  /// file, which empties it.
  private static func isWriteAheadLogEmpty(forStoreAt url: URL) -> Bool {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path + "-wal")
    return (attributes?[.size] as? Int ?? 0) == 0
  }
}
