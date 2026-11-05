//
//  ObserverModeTrackerTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

import Foundation
import StoreKit
import Testing
@testable import SuperwallKit

/// Keeps the observer mode keys in memory, behind a lock, and records every
/// save in order.
private final class ObserverModeStorage: Storage, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String: Any] = [:]
  private(set) var savedPurchasingIds: [Set<String>] = []
  private(set) var savedTransactionIds: [Set<UInt64>] = []

  init(
    purchasingIds: Set<String>? = nil,
    transactionIds: Set<UInt64>? = nil,
    didCacheLegacyTransactions: Bool? = nil
  ) {
    super.init(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: CacheMock(),
      coreDataManager: CoreDataManagerFakeDataMock()
    )
    values[PurchasingProductIds.key] = purchasingIds
    values[SK2TransactionIds.key] = transactionIds
    values[DidCacheLegacyTransactions.key] = didCacheLegacyTransactions
  }

  var saves: (purchasing: [Set<String>], transactions: [Set<UInt64>]) {
    lock.lock()
    defer { lock.unlock() }
    return (savedPurchasingIds, savedTransactionIds)
  }

  private func isObserverModeKey(_ key: String) -> Bool {
    key == PurchasingProductIds.key
      || key == SK2TransactionIds.key
      || key == DidCacheLegacyTransactions.key
  }

  private func read<Key: Storable>(_ keyType: Key.Type) -> Key.Value? {
    lock.lock()
    defer { lock.unlock() }
    return values[keyType.key] as? Key.Value
  }

  private func write<Key: Storable>(_ value: Key.Value, _ keyType: Key.Type) {
    lock.lock()
    defer { lock.unlock() }
    values[keyType.key] = value
    if let ids = value as? Set<String> {
      savedPurchasingIds.append(ids)
    }
    if let ids = value as? Set<UInt64> {
      savedTransactionIds.append(ids)
    }
  }

  override func get<Key>(_ keyType: Key.Type) -> Key.Value? where Key: Storable {
    isObserverModeKey(keyType.key) ? read(keyType) : super.get(keyType)
  }

  override func get<Key>(_ keyType: Key.Type) -> Key.Value? where Key: Storable, Key.Value: Decodable {
    isObserverModeKey(keyType.key) ? read(keyType) : super.get(keyType)
  }

  override func save<Key>(_ value: Key.Value, forType keyType: Key.Type) where Key: Storable {
    if isObserverModeKey(keyType.key) {
      return write(value, keyType)
    }
    super.save(value, forType: keyType)
  }

  override func save<Key>(_ value: Key.Value, forType keyType: Key.Type) where Key: Storable, Key.Value: Encodable {
    if isObserverModeKey(keyType.key) {
      return write(value, keyType)
    }
    super.save(value, forType: keyType)
  }
}

/// Returns no transactions, after a short wait, and records how many calls
/// overlapped.
private final class SlowEmptyTransactionsProvider: AllTransactionsProviderType, @unchecked Sendable {
  private let lock = NSLock()
  private var inFlight = 0
  private(set) var maxInFlight = 0
  private(set) var calls = 0

  var counts: (calls: Int, maxInFlight: Int) {
    lock.lock()
    defer { lock.unlock() }
    return (calls, maxInFlight)
  }

  func getAllTransactions() async -> [StoreKit.VerificationResult<StoreKit.Transaction>] {
    lock.lock()
    calls += 1
    inFlight += 1
    maxInFlight = max(maxInFlight, inFlight)
    lock.unlock()

    try? await Task.sleep(nanoseconds: 10_000_000)

    lock.lock()
    inFlight -= 1
    lock.unlock()
    return []
  }

  func getMostRecentVerifiedTransaction(
    from transactions: [StoreKit.VerificationResult<StoreKit.Transaction>]
  ) async -> StoreKit.VerificationResult<StoreKit.Transaction>? {
    return nil
  }
}

private func makeTracker(
  storage: ObserverModeStorage = ObserverModeStorage(),
  provider: AllTransactionsProviderType = SlowEmptyTransactionsProvider(),
  shouldObservePurchases: Bool = true
) -> (ObserverModeTracker, DependencyContainer) {
  let options = SuperwallOptions()
  options.shouldObservePurchases = shouldObservePurchases
  let container = DependencyContainer(options: options, cache: CacheMock())
  let tracker = ObserverModeTracker(
    storage: storage,
    productsManager: container.productsManager,
    allTransactionsProvider: provider,
    factory: container
  )
  return (tracker, container)
}

@Suite("ObserverModeUpdate reducers")
struct ObserverModeUpdateTests {
  @Test("startedPurchasing and removedFromQueue change the purchasing products")
  func purchasing() {
    let started = ObserverModeUpdate.startedPurchasing(productId: "a")
      .reduce(ObserverModeState(purchasingProductIds: ["b"]))
    #expect(started.purchasingProductIds == ["a", "b"])

    let removed = ObserverModeUpdate.removedFromQueue(productIds: ["a", "c"]).reduce(started)
    #expect(removed.purchasingProductIds == ["b"])
  }

  @Test("synced adds to the handled transactions")
  func synced() {
    let state = ObserverModeUpdate.synced(transactionIds: [2, 3])
      .reduce(ObserverModeState(syncedTransactionIds: [1]))
    #expect(state.syncedTransactionIds == [1, 2, 3])
  }

  @Test("clearedSyncedTransactions forgets the handled transactions only")
  func cleared() {
    let start = ObserverModeState(
      purchasingProductIds: ["a"],
      syncedTransactionIds: [1],
      didCacheLegacyTransactions: true
    )
    let state = ObserverModeUpdate.clearedSyncedTransactions.reduce(start)
    #expect(state.syncedTransactionIds.isEmpty)
    #expect(state.purchasingProductIds == ["a"])
    #expect(state.didCacheLegacyTransactions)
  }

  @Test("cachedLegacyTransactions adds the transactions and sets the flag")
  func cachedLegacy() {
    let state = ObserverModeUpdate.cachedLegacyTransactions([4])
      .reduce(ObserverModeState(syncedTransactionIds: [1]))
    #expect(state.syncedTransactionIds == [1, 4])
    #expect(state.didCacheLegacyTransactions)
  }
}

@Suite("ObserverModeTracker")
struct ObserverModeTrackerTests {
  @Test("loads what was saved")
  func loadsSavedState() {
    let storage = ObserverModeStorage(
      purchasingIds: ["a"],
      transactionIds: [1, 2],
      didCacheLegacyTransactions: true
    )
    let (tracker, _) = makeTracker(storage: storage)
    #expect(tracker.state == ObserverModeState(
      purchasingProductIds: ["a"],
      syncedTransactionIds: [1, 2],
      didCacheLegacyTransactions: true
    ))
  }

  @Test("a StoreKit 1 purchase is claimed once, however many threads try")
  func claimsSK1PurchaseOnce() async {
    let storage = ObserverModeStorage()
    let (tracker, _) = makeTracker(storage: storage)
    let claims = Claims()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<200 {
        group.addTask {
          tracker.store.dispatch(
            ObserverModeAction.claimSK1Purchase(productId: "product") { claims.add($0) },
            in: tracker
          )
        }
      }
    }

    #expect(claims.trueCount == 1)
    #expect(claims.count == 200)
    #expect(tracker.state.purchasingProductIds == ["product"])
    #expect(storage.saves.purchasing == [["product"]])
  }

  @Test("removing from the queue frees the product to be observed again")
  func removeFromQueue() {
    let storage = ObserverModeStorage(purchasingIds: ["a", "b"])
    let (tracker, _) = makeTracker(storage: storage)

    tracker.removeFromQueue(productIds: ["a"])

    #expect(tracker.state.purchasingProductIds == ["b"])
    #expect(storage.get(PurchasingProductIds.self) == ["b"])

    var isNew = false
    tracker.store.dispatch(
      ObserverModeAction.claimSK1Purchase(productId: "a") { isNew = $0 },
      in: tracker
    )
    #expect(isNew)
  }

  @Test("unsynced transactions are claimed only while the latest is unhandled")
  func claimsUnsyncedTransactions() {
    let (tracker, _) = makeTracker(storage: ObserverModeStorage(transactionIds: [1]))

    var first = false
    tracker.store.dispatch(
      ObserverModeAction.claimUnsyncedTransactions(transactionIds: [1, 2, 3], latestTransactionId: 3) { first = $0 },
      in: tracker
    )
    var second = true
    tracker.store.dispatch(
      ObserverModeAction.claimUnsyncedTransactions(transactionIds: [1, 2, 3], latestTransactionId: 3) { second = $0 },
      in: tracker
    )

    #expect(first)
    #expect(!second)
    #expect(tracker.state.syncedTransactionIds == [1, 2, 3])
  }

  @Test("200 concurrent updates are saved in the order they were applied")
  func savesInOrder() async {
    let storage = ObserverModeStorage()
    let (tracker, _) = makeTracker(storage: storage)

    await withTaskGroup(of: Void.self) { group in
      for id in 0..<200 {
        group.addTask {
          tracker.markSynced(transactionIds: [UInt64(id)])
        }
      }
    }

    let saves = storage.saves.transactions
    #expect(saves.count == 200)
    // Each save holds everything saved before it, so none overtook another.
    for (previous, next) in zip(saves, saves.dropFirst()) {
      #expect(next.isStrictSuperset(of: previous))
    }
    #expect(saves.last == Set((0..<200).map { UInt64($0) }))
    #expect(tracker.state.syncedTransactionIds == saves.last)
  }

  @Test("markSynced does nothing unless observing purchases")
  func markSyncedNeedsObserverMode() {
    let storage = ObserverModeStorage()
    let (tracker, _) = makeTracker(storage: storage, shouldObservePurchases: false)

    tracker.markSynced(transactionIds: [1])

    #expect(tracker.state.syncedTransactionIds.isEmpty)
    #expect(storage.saves.transactions.isEmpty)
  }

  @available(iOS 17.2, macOS 14.2, watchOS 10.2, tvOS 17.2, *)
  @Test("legacy transactions are cached once")
  func cachesLegacyTransactionsOnce() async {
    let provider = SlowEmptyTransactionsProvider()
    let storage = ObserverModeStorage(transactionIds: [7])
    let (tracker, _) = makeTracker(storage: storage, provider: provider)

    tracker.cacheLegacyTransactions()
    tracker.cacheLegacyTransactions()
    await tracker.operations.flush()

    #expect(provider.counts.calls == 1)
    #expect(tracker.state.didCacheLegacyTransactions)
    #expect(tracker.state.syncedTransactionIds == [7])
    #expect(storage.get(DidCacheLegacyTransactions.self) == true)
  }

  @available(iOS 17.2, macOS 14.2, watchOS 10.2, tvOS 17.2, *)
  @Test("detection waits for the legacy transactions to be cached")
  func detectionNeedsLegacyCache() async {
    let provider = SlowEmptyTransactionsProvider()
    let (tracker, _) = makeTracker(provider: provider)

    await tracker.detectUnobservedTransactions()
    #expect(provider.counts.calls == 0)

    tracker.cacheLegacyTransactions()
    await tracker.detectUnobservedTransactions()
    #expect(provider.counts.calls == 2)
  }

  @available(iOS 17.2, macOS 14.2, watchOS 10.2, tvOS 17.2, *)
  @Test("detections run one at a time")
  func detectionsDontOverlap() async {
    let provider = SlowEmptyTransactionsProvider()
    let storage = ObserverModeStorage(transactionIds: [1], didCacheLegacyTransactions: true)
    let (tracker, _) = makeTracker(storage: storage, provider: provider)

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<20 {
        group.addTask {
          await tracker.detectUnobservedTransactions()
        }
      }
    }

    #expect(provider.counts.calls == 20)
    #expect(provider.counts.maxInFlight == 1)
    // StoreKit had no transactions, so none are remembered.
    #expect(tracker.state.syncedTransactionIds.isEmpty)
    #expect(storage.get(SK2TransactionIds.self) == [])
  }
}

/// Returns the products it was given, or none, and counts the lookups.
private final class FakeProductsFetcher: ProductFetchable, @unchecked Sendable {
  private let lock = NSLock()
  private let products: Set<StoreProduct>
  private var internalLookups = 0

  init(products: Set<StoreProduct>) {
    self.products = products
  }

  var lookups: Int {
    lock.lock()
    defer { lock.unlock() }
    return internalLookups
  }

  func products(
    identifiers: Set<String>,
    forPaywall paywall: Paywall?,
    placement: PlacementData?
  ) async throws -> Set<StoreProduct> {
    lock.lock()
    internalLookups += 1
    lock.unlock()
    return products.filter { identifiers.contains($0.productIdentifier) }
  }
}

private final class TrackedEvents: @unchecked Sendable {
  private let lock = NSLock()
  private var events: [Trackable] = []

  func add(_ event: Trackable) {
    lock.lock()
    events.append(event)
    lock.unlock()
  }

  var transactions: [InternalSuperwallEvent.Transaction] {
    lock.lock()
    defer { lock.unlock() }
    return events.compactMap { $0 as? InternalSuperwallEvent.Transaction }
  }
}

@Suite("ObserverModeTracker StoreKit 1 purchases")
struct ObserverModeSK1PurchaseTests {
  private func makeSK1Tracker(
    products: Set<StoreProduct>
  ) -> (ObserverModeTracker, DependencyContainer, FakeProductsFetcher, TrackedEvents) {
    let options = SuperwallOptions()
    options.shouldObservePurchases = true
    options.storeKitVersion = .storeKit1
    let container = DependencyContainer(options: options, cache: CacheMock())
    let tracked = TrackedEvents()
    container.transactionManager.trackEvent = { tracked.add($0) }
    let fetcher = FakeProductsFetcher(products: products)
    let tracker = ObserverModeTracker(
      storage: ObserverModeStorage(),
      productsManager: ProductsManager(
        entitlementsInfo: container.entitlementsInfo,
        storeKitVersion: .storeKit1,
        productsFetcher: fetcher
      ),
      factory: container
    )
    return (tracker, container, fetcher, tracked)
  }

  @Test("observing a purchase starts an observed transaction once")
  func observesOnce() async {
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "monthly"))
    let (tracker, container, fetcher, tracked) = makeSK1Tracker(products: [product])

    await tracker.observeSK1Purchase(ofProductId: "monthly")
    await tracker.observeSK1Purchase(ofProductId: "monthly")

    #expect(fetcher.lookups == 1)
    let coordinator = container.makePurchasingCoordinator()
    #expect(await coordinator.product?.productIdentifier == "monthly")
    if case .observeFunc(let observed) = await coordinator.source {
      #expect(observed.productIdentifier == "monthly")
    } else {
      Issue.record("Expected an observed purchase")
    }
    let starts = tracked.transactions.filter {
      if case .start = $0.state { return true }
      return false
    }
    #expect(starts.count == 1)
    #expect(starts.first?.isObserved == true)
    #expect(tracker.state.purchasingProductIds == ["monthly"])
  }

  @Test("a product that can't be found is still remembered, and nothing starts")
  func missingProduct() async {
    let (tracker, container, fetcher, tracked) = makeSK1Tracker(products: [])

    await tracker.observeSK1Purchase(ofProductId: "missing")

    #expect(fetcher.lookups == 1)
    #expect(await container.makePurchasingCoordinator().source == nil)
    #expect(tracked.transactions.isEmpty)
    #expect(tracker.state.purchasingProductIds == ["missing"])
  }
}

private final class Claims: @unchecked Sendable {
  private let lock = NSLock()
  private var results: [Bool] = []

  func add(_ result: Bool) {
    lock.lock()
    results.append(result)
    lock.unlock()
  }

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return results.count
  }

  var trueCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return results.filter { $0 }.count
  }
}
