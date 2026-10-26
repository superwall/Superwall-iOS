//
//  CoreDataStoreLocation.swift
//  SuperwallKit
//

import Foundation
import CoreData

/// Where the Core Data store lives on disk.
///
/// The store used to sit in the root of Application Support, where Core Data
/// puts it by default. It now lives in its own folder so the SDK doesn't
/// clutter the host app's Application Support directory.
struct CoreDataStoreLocation {
  static let directoryName = "com.superwall.database.Store"

  /// Where the store lived before it moved into its own folder.
  let legacyUrl: URL

  /// Where the store lives now.
  let url: URL

  static let `default`: CoreDataStoreLocation = {
    let applicationSupportUrl = NSPersistentContainer.defaultDirectoryURL()
    let fileName = "\(CoreDataStack.modelName).sqlite"
    return CoreDataStoreLocation(
      legacyUrl: applicationSupportUrl.appendingPathComponent(fileName),
      url: applicationSupportUrl
        .appendingPathComponent(directoryName)
        .appendingPathComponent(fileName)
    )
  }()

  /// The store to open. This stays the legacy one until it has been moved,
  /// so its placements are never left behind if the move fails.
  var currentUrl: URL {
    if FileManager.default.fileExists(atPath: legacyUrl.path) {
      return legacyUrl
    }
    return url
  }

  /// Moves the legacy store into its own folder. Must run before anything
  /// opens the store.
  ///
  /// - Returns: `false` if the legacy store is still there and the move
  /// should be tried again.
  @discardableResult
  func moveLegacyStore() -> Bool {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: legacyUrl.path) {
      return true
    }

    let coordinator = NSPersistentStoreCoordinator(
      managedObjectModel: CoreDataStack.managedObject
    )
    do {
      try fileManager.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      // Copies the store along with any changes still in its -wal file,
      // replacing anything left at the new location by an earlier attempt.
      try coordinator.replacePersistentStore(
        at: url,
        destinationOptions: nil,
        withPersistentStoreFrom: legacyUrl,
        sourceOptions: nil,
        ofType: NSSQLiteStoreType
      )
      // Removing the main file is what switches the store over to the new
      // location, so it goes first. If that fails, the legacy store is still
      // whole and is used until the next attempt.
      try fileManager.removeItem(at: legacyUrl)
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .coreData,
        message: "Error moving the Core Data store into its own folder.",
        error: error
      )
      return false
    }

    for suffix in ["-wal", "-shm"] {
      let sidecarUrl = URL(fileURLWithPath: legacyUrl.path + suffix)
      try? fileManager.removeItem(at: sidecarUrl)
    }
    return true
  }
}
