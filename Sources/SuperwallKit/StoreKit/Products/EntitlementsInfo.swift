//
//  EntitlementsInfo.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/08/2024.
//

import Foundation
import Combine

/// A class that handles the `Set` of ``Entitlement`` objects retrieved from
/// the Superwall dashboard.
@objc(SWKEntitlementsInfo)
@objcMembers
public final class EntitlementsInfo: NSObject, ObservableObject, @unchecked Sendable {
  // MARK: - Public vars
  /// All entitlements, regardless of whether they're active or not.
  public var all: Set<Entitlement> {
    return store.state.all
  }

  /// The inactive entitlements.
  public var inactive: Set<Entitlement> {
    return store.state.inactive
  }

  /// The active entitlements.
  public var active: Set<Entitlement> {
    return store.state.active
  }

  /// A `Set` of active ``Entitlement`` objects redeemed via the web.
  public var web: Set<Entitlement> {
    let entitlements = storage.get(LatestRedeemResponse.self)?
      .customerInfo
      .entitlements
      .filter { $0.isActive } ?? []
    return Set(entitlements)
  }

  // MARK: - Internal vars
  /// The entitlements granted via ``Superwall/grantedEntitlements``.
  var granted: Set<Entitlement> {
    return store.state.granted
  }

  /// The published status, ``Superwall/subscriptionStatus``.
  var status: SubscriptionStatus {
    return store.state.status
  }

  /// The status last handed to the SDK, before granted entitlements and
  /// test-mode overrides were merged in.
  var assignedStatus: SubscriptionStatus {
    return store.state.assignedStatus
  }

  /// The entitlements that belong to each product ID.
  var entitlementsByProductId: [String: Set<Entitlement>] {
    get {
      return store.state.entitlementsByProductId
    }
    set {
      setEntitlementsFromConfig(newValue)
    }
  }

  /// Every change to the entitlements state goes through this store. The
  /// first use waits for the saved entitlements, which load in the background
  /// from when this object is created.
  var store: EntitlementsStore {
    savedEntitlements.wait()
    return loadedStore
  }

  /// Told about each status change once the store is unlocked, and asked for
  /// the test-mode override with it locked. Held weakly, and set once by
  /// ``Superwall``.
  var publisher: EntitlementsPublishing? {
    get {
      return publisherSlot.value
    }
    set {
      publisherSlot.value = newValue
    }
  }

  // MARK: - Private vars
  private unowned let storage: Storage
  private unowned let delegateAdapter: SuperwallDelegateAdapter
  private let publisherSlot: PublisherSlot
  private let publications: OrderedDelivery<EntitlementsPublication>
  /// The store itself. Only ``store`` and the load of the saved entitlements
  /// use it directly.
  private let loadedStore: EntitlementsStore
  private let savedEntitlements = BackgroundLoad(label: "com.superwall.entitlementsinfo.load")

  init(
    storage: Storage,
    delegateAdapter: SuperwallDelegateAdapter,
    isTesting: Bool = false
  ) {
    self.storage = storage
    self.delegateAdapter = delegateAdapter

    let loadedStore = EntitlementsStore(initial: EntitlementsState())
    self.loadedStore = loadedStore
    let publisherSlot = PublisherSlot()
    self.publisherSlot = publisherSlot
    publications = OrderedDelivery { publication in
      publisherSlot.value?.entitlementsDidPublish(publication)
    }
    super.init()

    // Loaded once and kept in memory, so later reads never hit disk. Most apps
    // never grant entitlements, and a storage miss isn't cached. Read off this
    // thread, which is usually the main thread at launch.
    savedEntitlements.start { [weak storage] in
      var byProductId: [String: Set<Entitlement>] = [:]
      if !isTesting {
        byProductId = storage?.get(EntitlementsByProductId.self) ?? [:]
      }
      loadedStore.update(
        EntitlementsUpdate.savedEntitlementsLoaded(
          granted: storage?.get(GrantedEntitlements.self) ?? [],
          byProductId: byProductId
        )
      )
    }
  }

  // MARK: - Public API

  /// Returns a `Set` of ``Entitlement``s belonging to a given `productId`.
  ///
  /// - Parameter productId: A `String` representing a `productId`
  /// - Returns: A `Set` of ``Entitlement``s
  public func byProductId(_ productId: String) -> Set<Entitlement> {
    return store.state.byProductId(productId)
  }

  /// Returns a `Set` of ``Entitlement`` objects belonging to a given set of `productId`s.
  ///
  /// - Parameter productIds: A `Set` of `String`s representing product identifiers.
  /// - Returns: A `Set` of ``Entitlement`` objects.
  public func byProductIds(_ productIds: Set<String>) -> Set<Entitlement> {
    return store.state.byProductIds(productIds)
  }

  // MARK: - Internal API

  /// Applies `change` and works out the published status from it.
  ///
  /// When this returns, ``status`` and ``active`` reflect the change, and the
  /// ``publisher`` has been told about it, unless another thread is telling
  /// it about earlier changes, in which case that thread hands this one over
  /// next.
  @discardableResult
  func publish(_ change: SubscriptionStatusChange) -> EntitlementsState {
    return store.dispatch(EntitlementsAction.changeStatus(change), in: self)
  }

  func setEntitlementsFromConfig(_ entitlementsByProductId: [String: Set<Entitlement>]) {
    store.dispatch(EntitlementsAction.receiveProductEntitlements(entitlementsByProductId), in: self)
  }
}

// MARK: - EntitlementsContext

extension EntitlementsInfo: EntitlementsContext {
  func currentTestModeOverride() -> SubscriptionStatus? {
    return publisher?.currentTestModeOverride()
  }

  // Storage writes hand off to a background queue, so they're safe with the
  // store locked, and they're made in the order the changes were applied.
  func saveProductMap(_ entitlementsByProductId: [String: Set<Entitlement>]) {
    storage.save(entitlementsByProductId, forType: EntitlementsByProductId.self)
  }

  func saveGranted(_ granted: Set<Entitlement>) {
    storage.save(granted, forType: GrantedEntitlements.self)
  }

  func saveAssignedStatus(_ status: SubscriptionStatus) {
    storage.save(status, forType: SubscriptionStatusKey.self)
  }

  func logGrantWarning() {
    Logger.debug(
      logLevel: .warn,
      scope: .grantedEntitlements,
      message: "subscriptionStatus was set to .inactive but grantedEntitlements "
        + "is not empty, so the status remains active. Assigning subscriptionStatus "
        + "doesn't clear granted entitlements — set grantedEntitlements to an empty set to revoke them."
    )
  }

  func queuePublication(_ publication: EntitlementsPublication) {
    publications.add(publication)
  }

  func deliverPublications() {
    publications.deliver()
  }
}

/// What ``EntitlementsInfo`` asks of the object that publishes the status.
protocol EntitlementsPublishing: AnyObject {
  /// The status test mode wants published, if any. Called with the
  /// entitlements store locked, so it must only read values, never wait.
  func currentTestModeOverride() -> SubscriptionStatus?

  /// Called once the store is unlocked, one change at a time, in the order the
  /// changes were applied.
  func entitlementsDidPublish(_ publication: EntitlementsPublication)
}

/// Work that starts on a background queue straight away, and that callers
/// can wait for.
private final class BackgroundLoad: @unchecked Sendable {
  private let queue: DispatchQueue
  private let lock = NSLock()
  private var isDone = false

  init(label: String) {
    queue = DispatchQueue(label: label, qos: .userInitiated)
  }

  func start(_ work: @escaping () -> Void) {
    queue.async { [self] in
      work()
      lock.lock()
      isDone = true
      lock.unlock()
    }
  }

  /// Returns once the work has finished. `work` must never call this.
  func wait() {
    lock.lock()
    let isDone = self.isDone
    lock.unlock()
    if isDone {
      return
    }
    // Waiting on the queue, rather than a semaphore, lends it this thread's
    // priority, so the main thread isn't held up by lower-priority work.
    queue.sync {}
  }
}

/// Holds the publisher weakly, behind a lock, so the delivery closure can
/// reach it without holding on to ``EntitlementsInfo``.
private final class PublisherSlot: @unchecked Sendable {
  private let lock = NSLock()
  private weak var publisher: EntitlementsPublishing?

  var value: EntitlementsPublishing? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return publisher
    }
    set {
      lock.lock()
      publisher = newValue
      lock.unlock()
    }
  }
}
