//
//  SavedPlacementTrimTests.swift
//  SuperwallKit
//
// swiftlint:disable all

import Testing
import Foundation
import CoreData
import SQLite3
@testable import SuperwallKit

struct SavedPlacementTrimTests {
  private let rootUrl = FileManager.default.temporaryDirectory
    .appendingPathComponent("SavedPlacementTrimTests-\(UUID().uuidString)")

  private var storeUrl: URL {
    rootUrl.appendingPathComponent("SuperwallKit_Model.sqlite")
  }

  private func makeStack() -> CoreDataStack {
    CoreDataStack(location: CoreDataStoreLocation(legacyUrl: storeUrl, url: storeUrl))
  }

  /// Saves placements the way earlier SDK versions did: every name, with its
  /// parameters.
  private func insert(
    _ count: Int,
    named name: String,
    parameters: Data,
    createdAt: Date = Date(),
    into stack: CoreDataStack
  ) throws {
    let context = try #require(stack.backgroundContext)
    try context.performAndWait {
      for _ in 0..<count {
        _ = ManagedEventData(
          context: context,
          id: UUID().uuidString,
          createdAt: createdAt,
          name: name,
          parameters: parameters
        )
      }
      try context.save()
      context.reset()
    }
  }

  private func count(_ name: String, in stack: CoreDataStack) async -> Int {
    let request = ManagedEventData.fetchRequest()
    request.predicate = NSPredicate(format: "name == %@", name)
    return await stack.count(for: request)
  }

  private func parameterBytes(in stack: CoreDataStack) throws -> Int {
    let context = try #require(stack.backgroundContext)
    return try context.performAndWait {
      context.reset()
      return try context.fetch(ManagedEventData.fetchRequest())
        .reduce(0) { $0 + $1.parameters.count }
    }
  }

  private func trim(_ manager: CoreDataManager) async {
    await withCheckedContinuation { continuation in
      manager.trimSavedPlacements {
        continuation.resume()
      }
    }
  }

  /// Waits for everything already queued on the manager's context.
  private func drain(_ manager: CoreDataManager) async {
    await withCheckedContinuation { continuation in
      guard let context = manager.backgroundContext else {
        return continuation.resume()
      }
      context.perform {
        continuation.resume()
      }
    }
  }

  private func goToBackground(_ center: NotificationCenter, _ manager: CoreDataManager) async {
    center.post(name: SystemInfo.applicationDidEnterBackgroundNotification, object: nil)
    await drain(manager)
  }

  private func spaceReclaimAttemptsLeft(_ stack: CoreDataStack) throws -> Int? {
    let coordinator = try #require(stack.persistentContainer?.persistentStoreCoordinator)
    let store = try #require(coordinator.persistentStores.first)
    return coordinator.metadata(for: store)[CoreDataManager.spaceReclaimAttemptsLeftKey] as? Int
  }

  /// Runs background work straight away, so a test can wait for it.
  private func lifecycle(_ center: NotificationCenter) -> CoreDataManager.AppLifecycle {
    CoreDataManager.AppLifecycle(notificationCenter: center) { work in
      work()
    }
  }

  /// Holds background work until a test lets it go, as the system does when
  /// it takes a moment to hand out background time.
  private final class HeldBackgroundWork {
    private let lock = NSLock()
    private var held: [() -> Void] = []

    func lifecycle(_ center: NotificationCenter) -> CoreDataManager.AppLifecycle {
      CoreDataManager.AppLifecycle(notificationCenter: center) { [self] work in
        lock.lock()
        held.append(work)
        lock.unlock()
      }
    }

    func runAll() {
      lock.lock()
      let work = held
      held = []
      lock.unlock()
      work.forEach { $0() }
    }
  }

  private func isFollowingTheApp(_ manager: CoreDataManager) async -> Bool {
    await withCheckedContinuation { continuation in
      guard let context = manager.backgroundContext else {
        return continuation.resume(returning: false)
      }
      context.perform {
        continuation.resume(returning: !manager.trimState.appBackgroundObservers.isEmpty)
      }
    }
  }

  /// Another connection with a read in progress, as a filter count in flight
  /// is. While it's open, the store's freed space can't be given back.
  private final class ReadInProgress {
    private var connection: OpaquePointer?
    private var statement: OpaquePointer?

    init(storeAt url: URL) throws {
      try #require(sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
      try #require(sqlite3_exec(connection, "BEGIN", nil, nil, nil) == SQLITE_OK)
      try #require(
        sqlite3_prepare_v2(connection, "SELECT count(*) FROM ZEVENTDATA", -1, &statement, nil) == SQLITE_OK
      )
      try #require(sqlite3_step(statement) == SQLITE_ROW)
    }

    func finish() {
      sqlite3_finalize(statement)
      sqlite3_exec(connection, "COMMIT", nil, nil, nil)
      sqlite3_close(connection)
      statement = nil
      connection = nil
    }
  }

  private func close(_ stack: CoreDataStack) throws {
    let coordinator = try #require(stack.persistentContainer?.persistentStoreCoordinator)
    for store in coordinator.persistentStores {
      try coordinator.remove(store)
    }
  }

  /// The store's size on disk, including changes SQLite hasn't yet moved out of
  /// its -wal file.
  private func sizeOnDisk() -> Int {
    ["", "-wal"].reduce(0) { total, suffix in
      let attributes = try? FileManager.default.attributesOfItem(atPath: storeUrl.path + suffix)
      return total + ((attributes?[.size] as? Int) ?? 0)
    }
  }

  private let largeParameters = Data(repeating: 7, count: 3_000)

  // MARK: - Saving

  @Test(arguments: [
    InternalSuperwallEvent.PaywallPreload(state: .start, paywallCount: 1).rawName,
    InternalSuperwallEvent.PaywallPreload(state: .complete, paywallCount: 1).rawName,
    InternalSuperwallEvent.PaywallLoad(state: .start, placementData: nil).rawName,
    InternalSuperwallEvent.PaywallLoad(state: .notFound, placementData: nil).rawName,
    InternalSuperwallEvent.PaywallLoad(state: .fail, placementData: nil).rawName,
    InternalSuperwallEvent.PaywallLoad(
      state: .complete(paywallInfo: .stub()),
      placementData: nil
    ).rawName,
    InternalSuperwallEvent.PaywallProductsLoad(
      state: .start,
      paywallInfo: .stub(),
      placementData: nil
    ).rawName,
    InternalSuperwallEvent.PaywallProductsLoad(
      state: .complete,
      paywallInfo: .stub(),
      placementData: nil
    ).rawName,
    InternalSuperwallEvent.PaywallProductsLoad(
      state: .retry(1),
      paywallInfo: .stub(),
      placementData: nil
    ).rawName,
    InternalSuperwallEvent.PaywallProductsLoad(
      state: .fail(NSError(domain: "test", code: 1)),
      paywallInfo: .stub(),
      placementData: nil
    ).rawName,
    InternalSuperwallEvent.PaywallProductsLoad(
      state: .missingProducts(["abc"]),
      paywallInfo: .stub(),
      placementData: nil
    ).rawName,
    InternalSuperwallEvent.PaywallWebviewLoad(
      state: .fail(NSError(domain: "test", code: 1), []),
      paywallInfo: .stub()
    ).rawName,
    InternalSuperwallEvent.PaywallWebviewLoad(state: .start, paywallInfo: .stub()).rawName,
    InternalSuperwallEvent.PaywallWebviewLoad(state: .complete, paywallInfo: .stub()).rawName,
    InternalSuperwallEvent.PaywallWebviewLoad(state: .timeout, paywallInfo: .stub()).rawName,
    InternalSuperwallEvent.PaywallWebviewLoad(state: .fallback, paywallInfo: .stub()).rawName,
    InternalSuperwallEvent.PaywallWebviewLoad(
      state: .processTerminated,
      paywallInfo: .stub()
    ).rawName,
    InternalSuperwallEvent.ShimmerLoad(state: .start, paywallId: "abc").rawName,
    InternalSuperwallEvent.ShimmerLoad(state: .complete, paywallId: "abc").rawName
  ])
  func loadingPlacementsArentSaved(name: String) {
    #expect(!CoreDataManager.isSaved(placementNamed: name))
  }

  @Test(arguments: [
    "app_install",
    "app_launch",
    "app_open",
    "session_start",
    "paywall_open",
    "paywall_close",
    "paywall_decline",
    "transaction_complete",
    "review_requested",
    "paywallPresentationRequest",
    "my_placement",
    // An app's own placements that only start like a loading one.
    "shimmerView_dismissed",
    "paywallPreload_seen"
  ])
  func otherPlacementsAreSaved(name: String) {
    #expect(CoreDataManager.isSaved(placementNamed: name))
  }

  @Test
  func savesWhenAPlacementHappenedWithoutItsParameters() async throws {
    let stack = CoreDataStackMock()
    let manager = CoreDataManagerMock(coreDataStack: stack)
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    manager.savePlacementData(
      .stub()
        .setting(\.name, to: "paywallWebviewLoad_complete")
        .setting(\.parameters, to: ["paywall_name": "abc"])
    )
    let saved: (name: String, createdAt: Date, parameters: Data) = await withCheckedContinuation { continuation in
      manager.savePlacementData(
        .stub()
          .setting(\.name, to: "paywall_open")
          .setting(\.createdAt, to: createdAt)
          .setting(\.parameters, to: ["paywall_name": "abc"])
      ) { placement in
        continuation.resume(returning: (placement.name, placement.createdAt, placement.parameters))
      }
    }

    #expect(saved.name == "paywall_open")
    #expect(saved.createdAt == createdAt)
    #expect(saved.parameters.isEmpty)
    // Saves run in order, so the loading placement would be there by now.
    #expect(await manager.countAllEvents() == 1)
  }

  // MARK: - Trimming a store saved by an earlier SDK version

  @Test
  func trimKeepsCountsAndDatesAndFreesSpace() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    let lastOpen = Date(timeIntervalSince1970: 1_700_000_000)
    try insert(600, named: "paywallWebviewLoad_complete", parameters: largeParameters, into: stack)
    try insert(600, named: "paywallResponseLoad_start", parameters: largeParameters, into: stack)
    try insert(300, named: "app_open", parameters: largeParameters, createdAt: lastOpen, into: stack)
    try insert(40, named: "paywallPreload_start", parameters: largeParameters, into: stack)
    try insert(
      1,
      named: "app_install",
      parameters: largeParameters,
      createdAt: lastOpen.addingTimeInterval(-86_400),
      into: stack
    )
    let sizeBefore = sizeOnDisk()
    let center = NotificationCenter()
    let manager = CoreDataManager(coreDataStack: stack, lifecycle: lifecycle(center))

    await trim(manager)

    #expect(await count("paywallWebviewLoad_complete", in: stack) == 0)
    #expect(await count("paywallResponseLoad_start", in: stack) == 0)
    #expect(await manager.countPlacement("app_open", interval: .infinity) == 300)
    #expect(await manager.countPlacement("app_install", interval: .infinity) == 1)
    #expect(await count("paywallPreload_start", in: stack) == 0)
    #expect(await stack.getLastSavedPlacementDate(name: "app_open", before: nil) == lastOpen)
    #expect(try parameterBytes(in: stack) == 0)

    // The space is only given back once the app is in the background, so that
    // rewriting the store doesn't hold up saves or a reset while it's in use.
    #expect(sizeBefore > 4_000_000)
    #expect(sizeOnDisk() > sizeBefore / 2)
    #expect(try spaceReclaimAttemptsLeft(stack) == CoreDataManager.spaceReclaimAttempts)

    await goToBackground(center, manager)

    // The store is still open here, as it is in an app.
    #expect(sizeOnDisk() < sizeBefore / 10)
    #expect(try spaceReclaimAttemptsLeft(stack) == 0)

    // It keeps working afterwards.
    await withCheckedContinuation { continuation in
      manager.savePlacementData(.stub().setting(\.name, to: "app_open")) { _ in
        continuation.resume()
      }
    }
    #expect(await manager.countPlacement("app_open", interval: .infinity) == 301)
  }

  @Test
  func countsAndDatesIgnoreLoadingPlacementsStillInTheStore() async throws {
    let stack = CoreDataStackMock()
    let manager = CoreDataManagerMock(coreDataStack: stack)
    await withCheckedContinuation { continuation in
      stack.batchInsertPlacementData(eventName: "paywallWebviewLoad_complete", count: 3) {
        continuation.resume()
      }
    }

    #expect(await manager.countAllEvents() == 3)
    #expect(await manager.countPlacement("paywallWebviewLoad_complete", interval: .infinity) == 0)
    #expect(await manager.countPlacement("paywallWebviewLoad_complete", since: nil) == 0)
    let daysSince = await manager.getComputedPropertySincePlacement(
      nil,
      request: ComputedPropertyRequest(type: .daysSince, placementName: "paywallWebviewLoad_complete")
    )
    #expect(daysSince == nil)
  }

  @Test
  func savingAPlacementDoesntWaitForTheWholeTrim() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    // Enough loading placements for the trim to need several steps.
    let loadingCount = CoreDataManager.trimBatchSize * 3
    try insert(loadingCount, named: "paywallWebviewLoad_complete", parameters: Data([7]), into: stack)
    try insert(
      CoreDataManager.trimBatchSize + 1,
      named: "app_open",
      parameters: Data([7]),
      into: stack
    )

    // Creating the manager starts the trim. The save is queued right behind
    // its first step.
    let manager = CoreDataManager(coreDataStack: stack)
    let loadingPlacementsLeftAtSave: Int = await withCheckedContinuation { continuation in
      manager.savePlacementData(.stub().setting(\.name, to: "paywall_open")) { placement in
        let request = ManagedEventData.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "paywallWebviewLoad_complete")
        let count = (try? placement.managedObjectContext?.count(for: request)) ?? -1
        continuation.resume(returning: count)
      }
    }
    #expect(loadingPlacementsLeftAtSave > 0)
    #expect(loadingPlacementsLeftAtSave < loadingCount)

    await trim(manager)
    #expect(await count("paywallWebviewLoad_complete", in: stack) == 0)
    #expect(await manager.countPlacement("app_open", interval: .infinity) == CoreDataManager.trimBatchSize + 1)
    #expect(await manager.countPlacement("paywall_open", interval: .infinity) == 1)
    #expect(try parameterBytes(in: stack) == 0)
  }

  @Test
  func spaceIsGivenBackOnALaterLaunchIfTheAppNeverWentToTheBackground() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    try insert(1_500, named: "paywallWebviewLoad_complete", parameters: largeParameters, into: stack)
    try insert(10, named: "app_open", parameters: largeParameters, into: stack)
    let sizeBefore = sizeOnDisk()
    await trim(CoreDataManager(coreDataStack: stack, lifecycle: lifecycle(NotificationCenter())))
    #expect(try spaceReclaimAttemptsLeft(stack) == CoreDataManager.spaceReclaimAttempts)
    try close(stack)

    // The next launch.
    let reopenedStack = makeStack()
    let center = NotificationCenter()
    let manager = CoreDataManager(coreDataStack: reopenedStack, lifecycle: lifecycle(center))
    await trim(manager)
    await goToBackground(center, manager)

    #expect(sizeOnDisk() < sizeBefore / 10)
    #expect(try spaceReclaimAttemptsLeft(reopenedStack) == 0)
    #expect(await manager.countPlacement("app_open", interval: .infinity) == 10)

    // Going to the background again has nothing left to do.
    try insert(1_500, named: "paywall_open", parameters: largeParameters, into: reopenedStack)
    let sizeWithNewRows = sizeOnDisk()
    await goToBackground(center, manager)
    #expect(sizeOnDisk() == sizeWithNewRows)
  }

  @Test
  func spaceIsGivenBackIfTheAppWentToTheBackgroundDuringTheTrim() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    // Enough for the trim to still be running when the app goes to the background.
    try insert(
      CoreDataManager.trimBatchSize * 3,
      named: "paywallWebviewLoad_complete",
      parameters: largeParameters,
      into: stack
    )
    let sizeBefore = sizeOnDisk()
    let center = NotificationCenter()
    let manager = CoreDataManager(coreDataStack: stack, lifecycle: lifecycle(center))

    // Queued behind the trim's first step, and ahead of its second.
    center.post(name: SystemInfo.applicationDidEnterBackgroundNotification, object: nil)

    await trim(manager)
    await drain(manager)
    #expect(sizeOnDisk() < sizeBefore / 10)
    #expect(try spaceReclaimAttemptsLeft(stack) == 0)
  }

  @Test
  func spaceIsKeptIfTheAppCameBackBeforeTheTrimFinished() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    try insert(
      CoreDataManager.trimBatchSize * 3,
      named: "paywallWebviewLoad_complete",
      parameters: largeParameters,
      into: stack
    )
    let sizeBefore = sizeOnDisk()
    let center = NotificationCenter()
    let manager = CoreDataManager(coreDataStack: stack, lifecycle: lifecycle(center))

    center.post(name: SystemInfo.applicationDidEnterBackgroundNotification, object: nil)
    center.post(name: SystemInfo.applicationWillEnterForegroundNotification, object: nil)

    await trim(manager)
    await drain(manager)
    #expect(sizeOnDisk() > sizeBefore / 2)
    #expect(try spaceReclaimAttemptsLeft(stack) == CoreDataManager.spaceReclaimAttempts)

    await goToBackground(center, manager)
    #expect(sizeOnDisk() < sizeBefore / 10)
  }

  @Test
  func spaceIsKeptIfTheAppCameBackBeforeTheBackgroundWorkGotItsTurn() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    try insert(1_500, named: "paywallWebviewLoad_complete", parameters: largeParameters, into: stack)
    let sizeBefore = sizeOnDisk()
    let center = NotificationCenter()
    let heldWork = HeldBackgroundWork()
    let manager = CoreDataManager(coreDataStack: stack, lifecycle: heldWork.lifecycle(center))
    await trim(manager)

    // The app goes to the background and comes back before the work runs.
    center.post(name: SystemInfo.applicationDidEnterBackgroundNotification, object: nil)
    center.post(name: SystemInfo.applicationWillEnterForegroundNotification, object: nil)
    await drain(manager)
    heldWork.runAll()
    await drain(manager)

    #expect(sizeOnDisk() > sizeBefore / 2)
    #expect(try spaceReclaimAttemptsLeft(stack) == CoreDataManager.spaceReclaimAttempts)

    // The next time it leaves, the work runs while it's still away.
    center.post(name: SystemInfo.applicationDidEnterBackgroundNotification, object: nil)
    await drain(manager)
    heldWork.runAll()
    await drain(manager)

    #expect(sizeOnDisk() < sizeBefore / 10)
    #expect(try spaceReclaimAttemptsLeft(stack) == 0)
  }

  @Test
  func aNewInstallIsDoneAfterGoingToTheBackgroundOnce() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    let center = NotificationCenter()
    let manager = CoreDataManager(coreDataStack: stack, lifecycle: lifecycle(center))
    await trim(manager)
    #expect(await isFollowingTheApp(manager))

    // There's nothing to give back, so the store doesn't get smaller. That
    // mustn't keep it trying.
    await goToBackground(center, manager)

    #expect(try spaceReclaimAttemptsLeft(stack) == 0)
    #expect(await isFollowingTheApp(manager) == false)
  }

  @Test
  func aReadInProgressIsntCountedAsDoneAndIsTriedAgain() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    try insert(1_500, named: "paywallWebviewLoad_complete", parameters: largeParameters, into: stack)
    let sizeBefore = sizeOnDisk()
    let center = NotificationCenter()
    let manager = CoreDataManager(coreDataStack: stack, lifecycle: lifecycle(center))
    await trim(manager)

    let read = try ReadInProgress(storeAt: storeUrl)
    let began = Date()
    await goToBackground(center, manager)

    // It gives up on this try quickly, and knows it didn't work.
    #expect(Date().timeIntervalSince(began) < 10)
    #expect(sizeOnDisk() > sizeBefore / 2)
    #expect(try spaceReclaimAttemptsLeft(stack) == CoreDataManager.spaceReclaimAttempts - 1)
    #expect(await isFollowingTheApp(manager))

    read.finish()
    await goToBackground(center, manager)

    #expect(sizeOnDisk() < sizeBefore / 10)
    #expect(try spaceReclaimAttemptsLeft(stack) == 0)
    #expect(await isFollowingTheApp(manager) == false)
  }

  @Test
  func givesUpAfterAFewTries() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    try insert(1_500, named: "paywallWebviewLoad_complete", parameters: largeParameters, into: stack)
    let center = NotificationCenter()
    let manager = CoreDataManager(coreDataStack: stack, lifecycle: lifecycle(center))
    await trim(manager)

    let read = try ReadInProgress(storeAt: storeUrl)
    defer { read.finish() }
    for _ in 0..<CoreDataManager.spaceReclaimAttempts {
      #expect(await isFollowingTheApp(manager))
      await goToBackground(center, manager)
    }

    #expect(try spaceReclaimAttemptsLeft(stack) == 0)
    #expect(await isFollowingTheApp(manager) == false)
    // The store still works.
    #expect(await count("paywallWebviewLoad_complete", in: stack) == 0)
    await withCheckedContinuation { continuation in
      manager.savePlacementData(.stub().setting(\.name, to: "app_open")) { _ in
        continuation.resume()
      }
    }
    #expect(await manager.countPlacement("app_open", interval: .infinity) == 1)
  }

  @Test
  func trimRunsOncePerStore() async throws {
    defer { try? FileManager.default.removeItem(at: rootUrl) }
    let stack = makeStack()
    try insert(5, named: "paywallWebviewLoad_complete", parameters: largeParameters, into: stack)
    let manager = CoreDataManager(coreDataStack: stack)
    await trim(manager)
    #expect(await count("paywallWebviewLoad_complete", in: stack) == 0)

    // Rows put in behind the manager's back show whether it trims again.
    try insert(2, named: "paywallWebviewLoad_complete", parameters: largeParameters, into: stack)
    await trim(manager)
    #expect(await count("paywallWebviewLoad_complete", in: stack) == 2)

    // And on the next launch.
    try close(stack)
    let reopenedStack = makeStack()
    await trim(CoreDataManager(coreDataStack: reopenedStack))
    #expect(await count("paywallWebviewLoad_complete", in: reopenedStack) == 2)
  }

  @Test
  func trimDoesNothingToAnInMemoryStore() async throws {
    let stack = CoreDataStackMock()
    let manager = CoreDataManagerMock(coreDataStack: stack)
    await withCheckedContinuation { continuation in
      stack.batchInsertPlacementData(eventName: "paywallWebviewLoad_complete", count: 3) {
        continuation.resume()
      }
    }

    await trim(manager)

    #expect(await manager.countAllEvents() == 3)
  }
}
