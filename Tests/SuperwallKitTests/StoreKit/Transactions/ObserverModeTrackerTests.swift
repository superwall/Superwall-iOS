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
    if keyType.key == PurchasingProductIds.key, let ids = value as? Set<String> {
      savedPurchasingIds.append(ids)
    }
    if keyType.key == SK2TransactionIds.key, let ids = value as? Set<UInt64> {
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

/// Records every side effect observer mode's actions cause, and returns the
/// transactions it's given.
private final class FakeObserverModeContext: ObserverModeContext, @unchecked Sendable {
  let store: ObserverModeStore
  private let lock = NSLock()
  private var internalObservesPurchases = true
  private var internalIsPurchaseInProgress = false
  private var internalTransactions = StoreKitTransactions(ids: [], latest: nil)
  private var internalSaves: [ObserverModeState] = []
  private var internalStartedObserving: [String] = []
  private var internalTracked: [ObservedTransaction] = []
  private var internalFetches = 0
  private var internalFollowUpsRanUnlocked: [Bool] = []
  /// Runs while a fetch is in progress, so a test can act during one.
  var duringFetch: (() -> Void)?

  init(_ state: ObserverModeState = ObserverModeState()) {
    store = ObserverModeStore(initial: state)
  }

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  var observesPurchases: Bool {
    get { locked { internalObservesPurchases } }
    set { locked { internalObservesPurchases = newValue } }
  }
  var isPurchaseInProgress: Bool {
    get { locked { internalIsPurchaseInProgress } }
    set { locked { internalIsPurchaseInProgress = newValue } }
  }
  var transactions: StoreKitTransactions {
    get { locked { internalTransactions } }
    set { locked { internalTransactions = newValue } }
  }
  var saves: [ObserverModeState] { locked { internalSaves } }
  var startedObserving: [String] { locked { internalStartedObserving } }
  var tracked: [ObservedTransaction] { locked { internalTracked } }
  var fetches: Int { locked { internalFetches } }
  var followUpsRanUnlocked: [Bool] { locked { internalFollowUpsRanUnlocked } }

  func fetchTransactions() async -> StoreKitTransactions {
    locked { internalFetches += 1 }
    duringFetch?()
    return transactions
  }

  func save(_ state: ObserverModeState) {
    locked { internalSaves.append(state) }
  }

  func startObserving(productId: String) {
    let unlocked = isStoreUnlocked()
    locked {
      internalStartedObserving.append(productId)
      internalFollowUpsRanUnlocked.append(unlocked)
    }
  }

  func trackObservedPurchase(_ transaction: ObservedTransaction) {
    let unlocked = isStoreUnlocked()
    locked {
      internalTracked.append(transaction)
      internalFollowUpsRanUnlocked.append(unlocked)
    }
  }

  /// Whether another thread can read the store right now.
  private func isStoreUnlocked() -> Bool {
    let read = DispatchSemaphore(value: 0)
    let store = self.store
    DispatchQueue.global().async {
      _ = store.state
      read.signal()
    }
    return read.wait(timeout: .now() + 1) == .success
  }

  @discardableResult
  func dispatch(_ action: ObserverModeAction) -> ObserverModeOutcome {
    store.dispatch(action, in: self)
  }
}

private func purchase(_ id: UInt64, product: String = "monthly", offer: Bool = false) -> ObservedTransaction {
  ObservedTransaction(id: id, productId: product, isPurchase: true, startedOffer: offer)
}

private func renewal(_ id: UInt64) -> ObservedTransaction {
  ObservedTransaction(id: id, productId: "monthly", isPurchase: false, startedOffer: false)
}

@Suite("ObserverModeUpdate events")
struct ObserverModeUpdateTests {
  @Test("purchasingStarted adds the product")
  func purchasingStarted() {
    let state = ObserverModeUpdate.purchasingStarted(productId: "a")
      .reduce(ObserverModeState(purchasingProductIds: ["b"]))
    #expect(state.purchasingProductIds == ["a", "b"])
  }

  @Test("leftPaymentQueue removes only the given products")
  func leftPaymentQueue() {
    let state = ObserverModeUpdate.leftPaymentQueue(productIds: ["a", "c"])
      .reduce(ObserverModeState(purchasingProductIds: ["a", "b"]))
    #expect(state.purchasingProductIds == ["b"])
  }

  @Test("transactionsHandled adds to the handled transactions")
  func transactionsHandled() {
    let state = ObserverModeUpdate.transactionsHandled([2, 3])
      .reduce(ObserverModeState(handledTransactionIds: [1]))
    #expect(state.handledTransactionIds == [1, 2, 3])
  }

  @Test("transactionsDisappeared removes only those transactions")
  func transactionsDisappeared() {
    let start = ObserverModeState(
      purchasingProductIds: ["a"],
      handledTransactionIds: [1, 2, 42],
      legacyRecording: .recorded
    )
    let state = ObserverModeUpdate.transactionsDisappeared([1, 2]).reduce(start)
    #expect(state.handledTransactionIds == [42])
    #expect(state.purchasingProductIds == ["a"])
    #expect(state.legacyRecording == .recorded)
  }

  @Test("legacyTransactionsRecorded keeps what's handled and marks the recording done")
  func legacyTransactionsRecorded() {
    let state = ObserverModeUpdate.legacyTransactionsRecorded([4])
      .reduce(ObserverModeState(handledTransactionIds: [1]))
    #expect(state.handledTransactionIds == [1, 4])
    #expect(state.legacyRecording == .recorded)
  }

  @Test("StoreKit 1 and StoreKit 2 events leave each other's fields alone")
  func independentFields() {
    let start = ObserverModeState(purchasingProductIds: ["a"], handledTransactionIds: [1])
    let handled = ObserverModeUpdate.transactionsHandled([2]).reduce(start)
    #expect(handled.purchasingProductIds == ["a"])
    #expect(handled.legacyRecording == .notRecorded)
    let left = ObserverModeUpdate.leftPaymentQueue(productIds: ["a"]).reduce(handled)
    #expect(left.handledTransactionIds == [1, 2])
  }
}

@Suite("ObserverModeAction")
struct ObserverModeActionTests {
  @Test("a StoreKit 1 purchase starts being observed once, however many threads try")
  func sk1PurchaseStartedOnce() async {
    let context = FakeObserverModeContext()
    let outcomes = OutcomeLog()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<200 {
        group.addTask {
          outcomes.add(context.dispatch(.sk1PurchaseStarted(productId: "monthly")))
        }
      }
    }

    #expect(outcomes.count(of: .startedObserving) == 1)
    #expect(outcomes.count(of: .unchanged) == 199)
    #expect(context.startedObserving == ["monthly"])
    #expect(context.saves.map(\.purchasingProductIds) == [["monthly"]])
    #expect(context.followUpsRanUnlocked == [true])
  }

  @Test("leaving the queue frees the product to be observed again")
  func sk1TransactionsLeftQueue() {
    let context = FakeObserverModeContext(ObserverModeState(purchasingProductIds: ["a", "b"]))

    #expect(context.dispatch(.sk1TransactionsLeftQueue(productIds: ["c"])) == .unchanged)
    #expect(context.dispatch(.sk1TransactionsLeftQueue(productIds: ["a"])) == .updated)
    #expect(context.store.state.purchasingProductIds == ["b"])
    #expect(context.dispatch(.sk1PurchaseStarted(productId: "a")) == .startedObserving)
  }

  @Test("a Superwall purchase is marked handled only when observing purchases")
  func sdkPurchaseCompleted() {
    let context = FakeObserverModeContext()
    context.observesPurchases = false
    #expect(context.dispatch(.sdkPurchaseCompleted(transactionIds: [1])) == .unchanged)
    #expect(context.saves.isEmpty)

    context.observesPurchases = true
    #expect(context.dispatch(.sdkPurchaseCompleted(transactionIds: [1])) == .updated)
    #expect(context.dispatch(.sdkPurchaseCompleted(transactionIds: [1])) == .unchanged)
    #expect(context.store.state.handledTransactionIds == [1])
    #expect(context.saves.count == 1)
  }

  @Test("legacy transactions are recorded once")
  func legacyTransactionsFetched() {
    let context = FakeObserverModeContext(ObserverModeState(handledTransactionIds: [9]))

    #expect(context.dispatch(.legacyTransactionsFetched([1, 2])) == .updated)
    #expect(context.dispatch(.legacyTransactionsFetched([3])) == .unchanged)
    #expect(context.store.state == ObserverModeState(
      handledTransactionIds: [1, 2, 9],
      legacyRecording: .recorded
    ))
  }

  @Test("a new purchase made by the app is handled and tracked once, after the store is unlocked")
  func tracksNewPurchase() {
    let context = FakeObserverModeContext(ObserverModeState(handledTransactionIds: [1]))
    let fetched = StoreKitTransactions(ids: [1, 2, 3], latest: purchase(3, offer: true))

    #expect(context.dispatch(.transactionsFetched(fetched, handledBeforeFetch: [1])) == .tracked)
    #expect(context.dispatch(.transactionsFetched(fetched, handledBeforeFetch: [1, 2, 3])) == .unchanged)

    #expect(context.tracked == [purchase(3, offer: true)])
    #expect(context.store.state.handledTransactionIds == [1, 2, 3])
    #expect(context.saves.last?.handledTransactionIds == [1, 2, 3])
    #expect(context.followUpsRanUnlocked == [true])
  }

  @Test("a renewal is marked handled but not tracked")
  func renewalIsNotTracked() {
    let context = FakeObserverModeContext()
    let fetched = StoreKitTransactions(ids: [1, 2], latest: renewal(2))

    #expect(context.dispatch(.transactionsFetched(fetched, handledBeforeFetch: [])) == .updated)
    #expect(context.tracked.isEmpty)
    #expect(context.store.state.handledTransactionIds == [1, 2])
  }

  @Test("nothing is tracked while a purchase is in progress")
  func purchaseInProgress() {
    let context = FakeObserverModeContext()
    context.isPurchaseInProgress = true
    let fetched = StoreKitTransactions(ids: [1], latest: purchase(1))

    #expect(context.dispatch(.transactionsFetched(fetched, handledBeforeFetch: [])) == .unchanged)
    #expect(context.tracked.isEmpty)
    #expect(context.store.state.handledTransactionIds.isEmpty)
  }

  @Test("a Superwall purchase marked handled first isn't tracked again by detection")
  func sdkPurchaseBeforeDetection() {
    let context = FakeObserverModeContext()
    context.dispatch(.sdkPurchaseCompleted(transactionIds: [5]))

    let fetched = StoreKitTransactions(ids: [5], latest: purchase(5))
    #expect(context.dispatch(.transactionsFetched(fetched, handledBeforeFetch: [5])) == .unchanged)
    #expect(context.tracked.isEmpty)
  }

  @Test("an empty fetch forgets only the transactions handled before it started")
  func emptyFetchForgetsWhatItSaw() {
    let context = FakeObserverModeContext(ObserverModeState(handledTransactionIds: [1, 2, 42]))
    let empty = StoreKitTransactions(ids: [], latest: nil)

    #expect(context.dispatch(.transactionsFetched(empty, handledBeforeFetch: [1, 2])) == .updated)
    #expect(context.store.state.handledTransactionIds == [42])
    #expect(context.dispatch(.transactionsFetched(empty, handledBeforeFetch: [1, 2])) == .unchanged)
  }

  @Test("transactions with no verified one are left alone")
  func noVerifiedTransaction() {
    let context = FakeObserverModeContext()
    let fetched = StoreKitTransactions(ids: [1], latest: nil)
    #expect(context.dispatch(.transactionsFetched(fetched, handledBeforeFetch: [])) == .unchanged)
    #expect(context.saves.isEmpty)
  }
}

@Suite("Observer mode lane steps")
struct ObserverModeLaneStepTests {
  @Test("detection does nothing until the legacy transactions are recorded")
  func needsLegacyRecording() async {
    let context = FakeObserverModeContext()
    context.transactions = StoreKitTransactions(ids: [1], latest: purchase(1))

    await context.detectUnobservedPurchase()
    #expect(context.fetches == 0)

    await context.recordLegacyTransactions()
    await context.recordLegacyTransactions()
    #expect(context.fetches == 1)
    #expect(context.store.state.legacyRecording == .recorded)
    // The purchase existed before observer mode, so it isn't tracked.
    await context.detectUnobservedPurchase()
    #expect(context.tracked.isEmpty)
  }

  @Test("detection skips the fetch while a purchase is in progress")
  func skipsWhilePurchasing() async {
    let context = FakeObserverModeContext(ObserverModeState(legacyRecording: .recorded))
    context.isPurchaseInProgress = true

    await context.detectUnobservedPurchase()

    #expect(context.fetches == 0)
  }

  @Test("a purchase that starts during the fetch isn't tracked by detection")
  func purchaseStartsDuringFetch() async {
    let context = FakeObserverModeContext(ObserverModeState(legacyRecording: .recorded))
    context.transactions = StoreKitTransactions(ids: [1], latest: purchase(1))
    context.duringFetch = { context.isPurchaseInProgress = true }

    await context.detectUnobservedPurchase()

    #expect(context.tracked.isEmpty)
    #expect(context.store.state.handledTransactionIds.isEmpty)
  }

  @Test("a Superwall purchase finished during an empty fetch stays handled")
  func sdkPurchaseDuringEmptyFetch() async {
    let context = FakeObserverModeContext(ObserverModeState(
      handledTransactionIds: [1],
      legacyRecording: .recorded
    ))
    context.duringFetch = { context.dispatch(.sdkPurchaseCompleted(transactionIds: [42])) }

    await context.detectUnobservedPurchase()

    #expect(context.store.state.handledTransactionIds == [42])
  }

  @Test("a new purchase is tracked through the context")
  func tracksThroughContext() async {
    let context = FakeObserverModeContext(ObserverModeState(legacyRecording: .recorded))
    context.transactions = StoreKitTransactions(ids: [7], latest: purchase(7, product: "annual"))

    await context.detectUnobservedPurchase()
    await context.detectUnobservedPurchase()

    #expect(context.tracked == [purchase(7, product: "annual")])
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
      handledTransactionIds: [1, 2],
      legacyRecording: .recorded
    ))

    let (fresh, _) = makeTracker()
    #expect(fresh.state.legacyRecording == .notRecorded)
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
    #expect(tracker.state.handledTransactionIds == saves.last)
  }

  @Test("a purchase in progress is seen without waiting")
  func seesPurchaseInProgress() async {
    let (tracker, container) = makeTracker()
    let coordinator = container.makePurchasingCoordinator()
    #expect(!tracker.isPurchaseInProgress)

    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "monthly"))
    coordinator.beginPurchase(of: product, source: .purchaseFunc(product), isFreeTrialAvailable: false)
    #expect(tracker.isPurchaseInProgress)

    coordinator.reset()
    #expect(!tracker.isPurchaseInProgress)
  }

  @Test("legacy transactions are recorded once")
  func recordsLegacyTransactionsOnce() async {
    let provider = SlowEmptyTransactionsProvider()
    let storage = ObserverModeStorage(transactionIds: [7])
    let (tracker, _) = makeTracker(storage: storage, provider: provider)

    tracker.cacheLegacyTransactions()
    tracker.cacheLegacyTransactions()
    await tracker.operations.flush()

    #expect(provider.counts.calls == 1)
    #expect(tracker.state.legacyRecording == .recorded)
    #expect(tracker.state.handledTransactionIds == [7])
    #expect(storage.get(DidCacheLegacyTransactions.self) == true)
  }

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
    // StoreKit had no transactions, so the one handled before is forgotten.
    #expect(tracker.state.handledTransactionIds.isEmpty)
    #expect(storage.get(SK2TransactionIds.self) == [])
  }
}

private final class OutcomeLog: @unchecked Sendable {
  private let lock = NSLock()
  private var outcomes: [ObserverModeOutcome] = []

  func add(_ outcome: ObserverModeOutcome) {
    lock.lock()
    outcomes.append(outcome)
    lock.unlock()
  }

  func count(of outcome: ObserverModeOutcome) -> Int {
    lock.lock()
    defer { lock.unlock() }
    return outcomes.filter { $0 == outcome }.count
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
    #expect(coordinator.purchase?.product.productIdentifier == "monthly")
    if case .observeFunc(let observed) = coordinator.purchase?.source {
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

  @Test("observing a second StoreKit 1 purchase abandons the first one, not the second")
  func observingSecondPurchaseAbandonsTheFirst() async throws {
    let first = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "first"))
    let second = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "second"))
    let (tracker, container, _, tracked) = makeSK1Tracker(products: [first, second])
    let coordinator = container.makePurchasingCoordinator()
    coordinator.reset()

    await tracker.observeSK1Purchase(ofProductId: "first")
    await tracker.observeSK1Purchase(ofProductId: "second")

    func abandoned() -> [String] {
      return tracked.transactions.compactMap {
        if case .abandon(let product) = $0.state {
          return product?.productIdentifier
        }
        return nil
      }
    }
    // The first purchase's completion is dropped, and handled in a task.
    for _ in 0..<200 where abandoned().isEmpty {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(abandoned() == ["first"])
    #expect(coordinator.purchase?.product.productIdentifier == "second")
    #expect(coordinator.hasPurchaseInProgress)
    coordinator.reset()
  }

  @Test("a product that can't be found is still remembered, and nothing starts")
  func missingProduct() async {
    let (tracker, container, fetcher, tracked) = makeSK1Tracker(products: [])

    await tracker.observeSK1Purchase(ofProductId: "missing")

    #expect(fetcher.lookups == 1)
    #expect(container.makePurchasingCoordinator().purchase == nil)
    #expect(tracked.transactions.isEmpty)
    #expect(tracker.state.purchasingProductIds == ["missing"])
  }
}

@Suite("ObserverModeTracker StoreKit 2 purchases")
struct ObserverModeSK2PurchaseTests {
  @Test("tracking a purchase the app made ends it, so the next one is tracked too")
  func trackedPurchaseEnds() async {
    let options = SuperwallOptions()
    options.shouldObservePurchases = true
    let container = DependencyContainer(options: options, cache: CacheMock())
    let tracked = TrackedEvents()
    container.transactionManager.trackEvent = { tracked.add($0) }
    let product = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "monthly"))
    // So tracking doesn't ask StoreKit for the transaction, which never
    // answers in a unit test.
    product.isCustomProduct = true
    let tracker = ObserverModeTracker(
      storage: ObserverModeStorage(),
      productsManager: ProductsManager(
        entitlementsInfo: container.entitlementsInfo,
        storeKitVersion: .storeKit2,
        productsFetcher: FakeProductsFetcher(products: [product])
      ),
      factory: container
    )
    let coordinator = container.makePurchasingCoordinator()
    coordinator.reset()

    tracker.trackObservedPurchase(
      ObservedTransaction(id: 1, productId: "monthly", isPurchase: true, startedOffer: false)
    )
    await tracker.operations.flush()

    #expect(!coordinator.hasPurchaseInProgress)
    #expect(!tracker.isPurchaseInProgress)
    let completions = tracked.transactions.filter {
      if case .complete = $0.state { return true }
      return false
    }
    #expect(completions.count == 1)
  }
}

/// Returns no transactions, but only once `release()` is called, so a test
/// can act while a fetch is in progress.
private final class HeldEmptyTransactionsProvider: AllTransactionsProviderType, @unchecked Sendable {
  private let lock = NSLock()
  private var holdNext = false
  private var waiting: [CheckedContinuation<Void, Never>] = []
  private var onHeld: [CheckedContinuation<Void, Never>] = []

  /// Holds the next fetch until `release()`.
  func holdNextFetch() {
    lock.lock()
    holdNext = true
    lock.unlock()
  }

  /// Returns once a fetch is being held.
  func waitUntilHeld() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if !waiting.isEmpty {
        lock.unlock()
        continuation.resume()
        return
      }
      onHeld.append(continuation)
      lock.unlock()
    }
  }

  func release() {
    lock.lock()
    let held = waiting
    waiting = []
    lock.unlock()
    held.forEach { $0.resume() }
  }

  func getAllTransactions() async -> [StoreKit.VerificationResult<StoreKit.Transaction>] {
    await withCheckedContinuation { continuation in
      lock.lock()
      if !holdNext {
        lock.unlock()
        continuation.resume()
        return
      }
      holdNext = false
      waiting.append(continuation)
      let held = onHeld
      onHeld = []
      lock.unlock()
      held.forEach { $0.resume() }
    }
    return []
  }

  func getMostRecentVerifiedTransaction(
    from transactions: [StoreKit.VerificationResult<StoreKit.Transaction>]
  ) async -> StoreKit.VerificationResult<StoreKit.Transaction>? {
    return nil
  }
}

@Suite("Observer mode regressions")
struct ObserverModeRegressionTests {
  @available(iOS 17.2, macOS 14.2, visionOS 1.1, watchOS 10.2, tvOS 17.2, *)
  @Test("a purchase finished during a fetch that found nothing stays handled")
  func clearKeepsTransactionsHandledDuringFetch() async {
    let provider = HeldEmptyTransactionsProvider()
    let (tracker, _) = makeTracker(
      storage: ObserverModeStorage(transactionIds: [1], didCacheLegacyTransactions: true),
      provider: provider
    )

    provider.holdNextFetch()
    let detection = Task {
      await tracker.detectUnobservedTransactions()
    }
    await provider.waitUntilHeld()

    // A purchase made through Superwall finishes while the fetch is running.
    tracker.markSynced(transactionIds: [42])
    provider.release()
    await detection.value

    // The fetch only proves the transactions it could have seen are gone.
    #expect(tracker.state.handledTransactionIds == [42])
  }
}
