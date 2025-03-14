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
  // MARK: - Public vars
  /// All entitlements, regardless of whether they're active or not.
  public private(set) var all: Set<Entitlement> {
    get {
      return queue.sync {
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

  /// The active entitlements.
  public var active: Set<Entitlement> {
    return queue.sync {
      return backingActive
    }
  }

  // MARK: - Internal vars
  /// The entitlements that belong to each product ID.
  var entitlementsByProductId: [String: Set<Entitlement>] = [:] {
    didSet {
      storage.save(entitlementsByProductId, forType: EntitlementsByProductId.self)
      self.all = Set(entitlementsByProductId.values.joined())
    }
  }

  // MARK: - Private vats
  /// The backing variable for ``EntitlementsInfo/active``.
  private var backingActive: Set<Entitlement> = []

  /// The backing variable for ``EntitlementsInfo/all``.
  private var backingAll: Set<Entitlement> = []

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

    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      entitlementsByProductId = self.storage.get(EntitlementsByProductId.self) ?? [:]

      backingAll = Set(entitlementsByProductId.values.joined())
    }
  }

  // MARK: - Public API

  /// Returns a `Set` of ``Entitlement``s belonging to a given `productId`.
  ///
  /// - Parameter productId: A `String` representing a `productId`
  /// - Returns: A `Set` of ``Entitlement``s
  public func byProductId(_ productId: String) -> Set<Entitlement> {
    return queue.sync {
      entitlementsByProductId[productId] ?? []
    }
  }

  // MARK: - Private API

  func mergeWebEntitlements(_ webEntitlements: Set<Entitlement>) {
    let localWithWeb = active.union(webEntitlements)
    Superwall.shared.subscriptionStatus = .active(localWithWeb)
  }

  func subscriptionStatusDidSet(_ subscriptionStatus: SubscriptionStatus) {
    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      switch subscriptionStatus {
      case .active(let entitlements):
        self.backingActive = entitlements
      default:
        self.backingActive = []
      }
    }
  }

  func setEntitlementsFromConfig(_ entitlementsByProductId: [String: Set<Entitlement>]) {
    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      self.entitlementsByProductId = entitlementsByProductId
    }
  }
}
