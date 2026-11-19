//
//  CoreDataManager+Trim.swift
//  SuperwallKit
//

import Foundation
import CoreData

extension CoreDataManager {
  /// Set in the store's metadata once `trimSavedPlacements` has run on it.
  static let didTrimSavedPlacementsKey = "SWKDidTrimSavedPlacements"

  /// Shrinks a store that already holds loading placements and parameters,
  /// then gives the freed space back to the device. Runs once per store, in
  /// the background.
  func trimSavedPlacements(completion: (() -> Void)? = nil) {
    guard
      let backgroundContext = backgroundContext,
      let coordinator = coreDataStack.persistentContainer?.persistentStoreCoordinator,
      let store = coordinator.persistentStores.first,
      store.type == NSSQLiteStoreType,
      let storeUrl = store.url
    else {
      completion?()
      return
    }

    backgroundContext.perform {
      defer {
        completion?()
      }
      var metadata = coordinator.metadata(for: store)
      if metadata[Self.didTrimSavedPlacementsKey] as? Bool == true {
        return
      }

      do {
        let loadingPlacementsRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
          entityName: ManagedEventData.entityName
        )
        loadingPlacementsRequest.predicate = NSCompoundPredicate(
          orPredicateWithSubpredicates: Self.unsavedPlacementPrefixes.map {
            NSPredicate(format: "name BEGINSWITH %@", $0)
          }
        )
        try backgroundContext.executeAndMergeChanges(
          using: NSBatchDeleteRequest(fetchRequest: loadingPlacementsRequest)
        )

        let emptyParametersRequest = NSBatchUpdateRequest(entityName: ManagedEventData.entityName)
        emptyParametersRequest.predicate = NSPredicate(format: "parameters != %@", Data() as NSData)
        emptyParametersRequest.propertiesToUpdate = [
          "parameters": NSExpression(forConstantValue: Data())
        ]
        try backgroundContext.execute(emptyParametersRequest)

        try Self.reclaimFreeSpace(inStoreAt: storeUrl)

        metadata[Self.didTrimSavedPlacementsKey] = true
        coordinator.setMetadata(metadata, for: store)
        try backgroundContext.save()
      } catch {
        // The key isn't set, so this runs again on the next launch.
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Could not trim saved placements.",
          error: error
        )
      }
    }
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
