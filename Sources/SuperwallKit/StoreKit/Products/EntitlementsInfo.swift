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
      store.update(EntitlementsUpdate.productEntitlements(newValue))
    }
  }

  /// Every change to the entitlements state goes through this store. Its
  /// observers save each change and publish the status, in the order the
  /// changes were applied.
  let store: EntitlementsStore

  // MARK: - Private vars
  private unowned let storage: Storage
  private unowned let delegateAdapter: SuperwallDelegateAdapter

  init(
    storage: Storage,
    delegateAdapter: SuperwallDelegateAdapter,
    isTesting: Bool = false
  ) {
    self.storage = storage
    self.delegateAdapter = delegateAdapter

    // Loaded once here and kept in memory, so reads never hit disk. Most apps
    // never grant entitlements, and a storage miss isn't cached.
    var initial = EntitlementsState(granted: storage.get(GrantedEntitlements.self) ?? [])
    if !isTesting {
      initial.entitlementsByProductId = storage.get(EntitlementsByProductId.self) ?? [:]
    }
    store = EntitlementsStore(initial: initial)
    super.init()

    store.observe { [weak self] before, after in
      self?.save(before: before, after: after)
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
  /// When this returns, ``status`` and ``active`` reflect the change, and any
  /// receiver given to ``publishStatusChanges(to:)`` has been handed the new
  /// status, unless another thread is handing it statuses, in which case that
  /// thread hands this one over next.
  func publish(
    _ change: SubscriptionStatusChange,
    testModeOverride: SubscriptionStatus? = nil
  ) {
    store.update(EntitlementsUpdate.publish(change, testModeOverride: testModeOverride))
  }

  func setEntitlementsFromConfig(_ entitlementsByProductId: [String: Set<Entitlement>]) {
    store.update(EntitlementsUpdate.productEntitlements(entitlementsByProductId))
  }

  /// Hands every later change of the published status to `receive`, in the
  /// order the changes were applied, with the store unlocked.
  func publishStatusChanges(to receive: @escaping (SubscriptionStatus) -> Void) {
    let delivery = OrderedDelivery(receive)
    store.observe { [weak store] before, after in
      if before.status == after.status {
        return
      }
      delivery.add(after.status)
      store?.deferUntilUnlocked {
        delivery.deliver()
      }
    }
  }

  // MARK: - Private API

  /// Saves what changed. Storage writes hand off to a background queue, so
  /// they're safe with the store locked, and they're made in the order the
  /// changes were applied.
  private func save(before: EntitlementsState, after: EntitlementsState) {
    if before.entitlementsByProductId != after.entitlementsByProductId {
      storage.save(after.entitlementsByProductId, forType: EntitlementsByProductId.self)
    }
    if before.granted != after.granted {
      storage.save(after.granted, forType: GrantedEntitlements.self)
    }
    // The assigned value is saved, not the published one: restoring a
    // published value would make granted entitlements part of the assigned
    // status for good, so they couldn't be cleared after a relaunch.
    if before.assignedStatus != after.assignedStatus {
      storage.save(after.assignedStatus, forType: SubscriptionStatusKey.self)
    }
    if !before.hasGrantedEntitlementsWarning,
      after.hasGrantedEntitlementsWarning {
      store.deferUntilUnlocked {
        Logger.debug(
          logLevel: .warn,
          scope: .grantedEntitlements,
          message: "subscriptionStatus was set to .inactive but grantedEntitlements "
            + "is not empty, so the status remains active. Assigning subscriptionStatus "
            + "doesn't clear granted entitlements — set grantedEntitlements to an empty set to revoke them."
        )
      }
    }
  }
}
