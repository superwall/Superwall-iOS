//
//  CoreDataStoreLocationTests.swift
//  SuperwallKit
//
// swiftlint:disable all

import Testing
import Foundation
import CoreData
@testable import SuperwallKit

struct CoreDataStoreLocationTests {
  private let rootUrl = FileManager.default.temporaryDirectory
    .appendingPathComponent("CoreDataStoreLocationTests-\(UUID().uuidString)")

  private var location: CoreDataStoreLocation {
    CoreDataStoreLocation(
      legacyUrl: rootUrl.appendingPathComponent("SuperwallKit_Model.sqlite"),
      url: rootUrl
        .appendingPathComponent(CoreDataStoreLocation.directoryName)
        .appendingPathComponent("SuperwallKit_Model.sqlite")
    )
  }

  /// Saves placements into a store at the legacy location, then closes it.
  private func makeLegacyStore(placementCount: Int) throws {
    let legacyUrl = location.legacyUrl
    let stack = CoreDataStack(
      location: CoreDataStoreLocation(legacyUrl: legacyUrl, url: legacyUrl)
    )
    let context = try #require(stack.backgroundContext)
    try context.performAndWait {
      for _ in 0..<placementCount {
        _ = ManagedEventData(
          context: context,
          id: UUID().uuidString,
          createdAt: Date(),
          name: "placement",
          parameters: Data()
        )
      }
      try context.save()
    }
    let coordinator = try #require(stack.persistentContainer?.persistentStoreCoordinator)
    for store in coordinator.persistentStores {
      try coordinator.remove(store)
    }
  }

  /// Leaves a legacy store whose placements are only in its -wal file, as
  /// happens when the app is killed before SQLite writes them into the main
  /// file.
  private func makeLegacyStoreWithPlacementsOnlyInWal(placementCount: Int) throws {
    let liveUrl = rootUrl
      .appendingPathComponent("live")
      .appendingPathComponent("SuperwallKit_Model.sqlite")
    try FileManager.default.createDirectory(
      at: liveUrl.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let container = NSPersistentContainer(
      name: CoreDataStack.modelName,
      managedObjectModel: CoreDataStack.managedObject
    )
    let description = NSPersistentStoreDescription(url: liveUrl)
    description.shouldAddStoreAsynchronously = false
    description.setOption(
      ["wal_autocheckpoint": "0"] as NSDictionary,
      forKey: NSSQLitePragmasOption
    )
    container.persistentStoreDescriptions = [description]
    var loadError: Error?
    container.loadPersistentStores { _, error in loadError = error }
    if let loadError {
      throw loadError
    }

    let context = container.newBackgroundContext()
    try context.performAndWait {
      for _ in 0..<placementCount {
        _ = ManagedEventData(
          context: context,
          id: UUID().uuidString,
          createdAt: Date(),
          name: "placement",
          parameters: Data()
        )
      }
      try context.save()
    }

    // Copy the files while the store is still open, before closing it writes
    // the -wal changes into the main file.
    try FileManager.default.createDirectory(at: rootUrl, withIntermediateDirectories: true)
    for suffix in ["", "-wal", "-shm"] {
      try FileManager.default.copyItem(
        atPath: liveUrl.path + suffix,
        toPath: location.legacyUrl.path + suffix
      )
    }
    for store in container.persistentStoreCoordinator.persistentStores {
      try container.persistentStoreCoordinator.remove(store)
    }

    let walSize = try FileManager.default
      .attributesOfItem(atPath: location.legacyUrl.path + "-wal")[.size] as? Int
    #expect((walSize ?? 0) > 0)
  }

  private func placementCount(in stack: CoreDataStack) async -> Int {
    await stack.count(for: ManagedEventData.fetchRequest())
  }

  @Test
  func movesLegacyStoreKeepingPlacements() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    try makeLegacyStore(placementCount: 3)
    let cache = CacheMock()
    cache.write(.v5, forType: Version.self)

    V5Migrator.migrateToNextVersion(cache: cache, coreDataStoreLocation: location)

    let fileManager = FileManager.default
    #expect(!fileManager.fileExists(atPath: location.legacyUrl.path))
    #expect(!fileManager.fileExists(atPath: location.legacyUrl.path + "-wal"))
    #expect(!fileManager.fileExists(atPath: location.legacyUrl.path + "-shm"))
    #expect(fileManager.fileExists(atPath: location.url.path))
    #expect(location.currentUrl == location.url)
    #expect(cache.read(Version.self) == .v6)

    let stack = CoreDataStack(location: location)
    #expect(await placementCount(in: stack) == 3)
  }

  @Test
  func movesPlacementsStillInWalFile() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    try makeLegacyStoreWithPlacementsOnlyInWal(placementCount: 5)

    #expect(location.moveLegacyStore())

    #expect(!FileManager.default.fileExists(atPath: location.legacyUrl.path))
    let stack = CoreDataStack(location: location)
    #expect(await placementCount(in: stack) == 5)
  }

  @Test
  func failedMoveKeepsUsingLegacyStore() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    try makeLegacyStore(placementCount: 2)
    // A file where the new folder should go makes the move fail.
    let folderUrl = location.url.deletingLastPathComponent()
    #expect(FileManager.default.createFile(atPath: folderUrl.path, contents: Data()))
    let cache = CacheMock()
    cache.write(.v5, forType: Version.self)

    V5Migrator.migrateToNextVersion(cache: cache, coreDataStoreLocation: location)

    #expect(FileManager.default.fileExists(atPath: location.legacyUrl.path))
    #expect(location.currentUrl == location.legacyUrl)
    // The version isn't bumped, so the move is tried again next launch.
    #expect(cache.read(Version.self) == .v5)

    let stack = CoreDataStack(location: location)
    #expect(await placementCount(in: stack) == 2)
  }

  @Test
  func retriedMoveReplacesStoreLeftByEarlierAttempt() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    // An earlier attempt copied the store but couldn't remove the legacy
    // one, and placements kept being saved to the legacy store after that.
    try makeLegacyStore(placementCount: 1)
    #expect(location.moveLegacyStore())
    try makeLegacyStore(placementCount: 4)

    #expect(location.moveLegacyStore())

    let stack = CoreDataStack(location: location)
    #expect(await placementCount(in: stack) == 4)
  }

  @Test
  func noLegacyStoreBumpsVersion() {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let cache = CacheMock()
    cache.write(.v5, forType: Version.self)

    V5Migrator.migrateToNextVersion(cache: cache, coreDataStoreLocation: location)

    #expect(cache.read(Version.self) == .v6)
    #expect(!FileManager.default.fileExists(atPath: location.url.path))
    #expect(location.currentUrl == location.url)
  }

  @Test
  func defaultLocationUsesOwnFolderInApplicationSupport() {
    let applicationSupportUrl = NSPersistentContainer.defaultDirectoryURL()
    let location = CoreDataStoreLocation.default

    #expect(location.legacyUrl.deletingLastPathComponent().path == applicationSupportUrl.path)
    #expect(
      location.url.deletingLastPathComponent().path
        == applicationSupportUrl.appendingPathComponent(CoreDataStoreLocation.directoryName).path
    )
    #expect(location.url.lastPathComponent == "SuperwallKit_Model.sqlite")
  }
}
