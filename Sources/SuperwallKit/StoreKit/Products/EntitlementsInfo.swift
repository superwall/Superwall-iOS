//
//  File.swift
//  
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
  /// The backing variable for ``EntitlementsInfo/active``.
  private var backingActive: Set<Entitlement> = []

  /// The active entitlements.
  ///
  /// When this changes, the delegate method ``SuperwallDelegate/activeEntitlementsDidChange(to:)``
  /// will fire with the new value.
  ///
  /// The first time this is set ``EntitlementsInfo/didSetActiveEntitlements`` will
  /// become `true`.
  public private(set) var active: Set<Entitlement> {
    get {
      queue.sync {
        return backingActive
      }
    }
    set {
      queue.async { [weak self] in
        guard let self = self else {
          return
        }
        let oldValue = self.backingActive

        if didSetActiveEntitlements == false {
          DispatchQueue.main.async {
            self.didSetActiveEntitlements = true
            self.delegateAdapter.activeEntitlementsDidChange(to: newValue)
          }
        }
        guard newValue != oldValue else {
          return
        }
        self.backingActive = newValue

        DispatchQueue.main.async {
          self.publishedActive = newValue
          self.didSetActiveEntitlements = true
        }
        activeEntitlementsChanged(
          oldValue: oldValue,
          newValue: newValue
        )
      }
    }
  }

  /// A published property for ``EntitlementsInfo/active``.
  ///
  /// You can bind to this to be notified when active entitlements change.
  @MainActor @Published public private(set) var publishedActive: Set<Entitlement> = []

  private func activeEntitlementsChanged(
    oldValue: Set<Entitlement>,
    newValue: Set<Entitlement>
  ) {
    storage.save(newValue, forType: ActiveEntitlements.self)

    Task {
      await delegateAdapter.activeEntitlementsDidChange(to: newValue)
      let event = InternalSuperwallPlacement.ActiveEntitlementsDidChange(activeEntitlements: newValue)
      await Superwall.shared.track(event)
    }
  }

  /// When the active entitlements have been set.
  @Published public private(set) var didSetActiveEntitlements = false

  /// The backing variable for ``EntitlementsInfo/all``.
  private var backingAll: Set<Entitlement> = []

  /// All entitlements, regardless of whether they're active or not.
  public private(set) var all: Set<Entitlement> {
    get {
      queue.sync {
        return backingAll
      }
    }
    set {
      queue.async {
        self.backingAll = newValue
      }
    }
  }

  /// The inactive entitlements.
  public var inactive: Set<Entitlement> {
    return queue.sync {
      return backingAll.subtracting(backingActive)
    }
  }

  /// The entitlements that belong to each product ID.
  var entitlementsByProductId: [String: Set<Entitlement>] = [:] {
    didSet {
      storage.save(entitlementsByProductId, forType: EntitlementsByProductId.self)
      self.all = Set(entitlementsByProductId.values.joined())
    }
  }

  private unowned let storage: Storage
  private unowned let delegateAdapter: SuperwallDelegateAdapter
  private let queue = DispatchQueue(label: "com.superwall.entitlementsinfo.queue")

  init(
    storage: Storage,
    delegateAdapter: SuperwallDelegateAdapter,
    isTesting: Bool = false
  ) {
    self.storage = storage
    self.delegateAdapter = delegateAdapter
    super.init()
    if isTesting {
      return
    }

    queue.sync {
      entitlementsByProductId = storage.get(EntitlementsByProductId.self) ?? [:]

      if let activeEntitlements = storage.get(ActiveEntitlements.self) {
        backingActive = activeEntitlements

        // First time
        DispatchQueue.main.async { [weak self] in
          self?.publishedActive = activeEntitlements
          self?.didSetActiveEntitlements = true
          self?.delegateAdapter.activeEntitlementsDidChange(to: activeEntitlements)
        }
      } else {
        backingActive = []
      }

      backingAll = Set(entitlementsByProductId.values.joined())
    }
  }

  /// Sets the active entitlements.
  ///
  /// - Parameter entitlements: A `Set` of ``Entitlement`` objects.
  @objc(setActiveEntitlements:)
  public func set(_ activeEntitlements: Set<Entitlement>) {
    active = activeEntitlements
  }

  /// Sets the active entitlements.
  ///
  /// - Parameter entitlements: A `Set` of ``Entitlement`` objects.
  @nonobjc
  public func set(_ activeEntitlements: [Entitlement]) {
    active = Set(activeEntitlements)
  }

  /// Returns a `Set` of ``Entitlement``s belonging to a given `productId`.
  ///
  /// - Parameter productId: A `String` representing a `productId`
  /// - Returns: A `Set` of ``Entitlement``s
  public func byProductId(_ productId: String) -> Set<Entitlement> {
    return queue.sync {
      entitlementsByProductId[productId] ?? []
    }
  }
}
