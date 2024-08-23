//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/08/2024.
//

import Foundation
import Combine

// TODO: Figure out the synchronisation of entitlements.
/*
 All Published properties have to be set on the main thread.
 The caller of the API can't know about that
 */

/// A class that handles the `Set` of ``Entitlement`` objects retrieved from
/// the Superwall dashboard.
@objc(SWKEntitlementsInfo)
@objcMembers
public final class EntitlementsInfo: NSObject {
  private unowned let storage: Storage
  private unowned let delegateAdapter: SuperwallDelegateAdapter

  /// The active entitlements.
  @Published public private(set) var active: Set<Entitlement> = [] {
    didSet {
      didSetActiveEntitlements = true
      storage.save(active, forType: ActiveEntitlements.self)

      if oldValue != active {
        Task {
          await handleActiveEntitlementsChange(newValue: active)
        }
      }
    }
  }

  /// All entitlements, regardless of whether they're active or not.
  public private(set) var all: Set<Entitlement> = []

  /// The inactive entitlements.
  public var inactive: Set<Entitlement> {
    return all.subtracting(active)
  }

  /// The entitlements that belong to each product ID.
  var entitlementsByProductId: [String: Set<Entitlement>] = [:] {
    didSet {
      storage.save(entitlementsByProductId, forType: EntitlementsByProductId.self)
      self.all = Set(entitlementsByProductId.values.joined())
    }
  }

  /// When the active entitlements have been set.
  @Published public var didSetActiveEntitlements = false

  init(
    storage: Storage,
    delegateAdapter: SuperwallDelegateAdapter
  ) {
    self.storage = storage
    self.delegateAdapter = delegateAdapter
    super.init()
    entitlementsByProductId = storage.get(EntitlementsByProductId.self) ?? [:]

    if let activeEntitlements = storage.get(ActiveEntitlements.self) {
      active = activeEntitlements
      didSetActiveEntitlements = true
    } else {
      active = []
    }
  }

  private func handleActiveEntitlementsChange(newValue: Set<Entitlement>) async {
    await delegateAdapter.activeEntitlementsDidChange(to: newValue)
    let event = InternalSuperwallEvent.ActiveEntitlementsDidChange(activeEntitlements: newValue)
    await Superwall.shared.track(event)
  }

  /// Sets the active entitlements.
  ///
  /// - Parameter entitlements: A `Set` of ``Entitlement`` objects.
  @objc(setActiveEntitlements:)
  public func set(_ entitlements: Set<Entitlement>) {
      active = entitlements
  }

  /// Sets the active entitlements.
  ///
  /// - Parameter entitlements: A `Set` of ``Entitlement`` objects.
  @nonobjc
  public func set(_ entitlements: [Entitlement]) {
      active = Set(entitlements)
  }

  /// Returns a `Set` of ``Entitlement``s belonging to a given `productId`.
  ///
  /// - Parameter productId: A `String` representing a `productId`
  /// - Returns: A `Set` of ``Entitlement``s
  public func byProductId(_ productId: String) -> Set<Entitlement> {
    return entitlementsByProductId[productId] ?? []
  }
}
