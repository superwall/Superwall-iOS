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
  public private(set) var active: Set<Entitlement> {
    get {
      return queue.sync {
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
          }
        }
        storage.save(newValue, forType: ActiveEntitlements.self)

        guard newValue != oldValue else {
          return
        }
        self.backingActive = newValue

        DispatchQueue.main.async {
          self.publishedActive = newValue
          self.didSetActiveEntitlements = true
        }
      }
    }
  }

  /// A published, read-only property that indicates the entitlement status of the user.
  ///
  /// If you're using Combine or SwiftUI, you can subscribe or bind to it to get
  /// notified whenever it changes.
  ///
  /// Otherwise, you can check the delegate function
  /// ``SuperwallDelegate/entitlementStatusDidChange(to:)``
  /// to receive a callback with the new value every time it changes.
  @Published public private(set) var status: EntitlementStatus = .unknown

  // MARK: - Internal vars
  /// A published property for ``EntitlementsInfo/active``.
  ///
  /// You can bind to this to be notified when active entitlements change.
  @Published private(set) var publishedActive: Set<Entitlement> = []

  /// When the active entitlements have been set.
  @Published private(set) var didSetActiveEntitlements = false

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

    DispatchQueue.main.async { [weak self] in
      self?.listenToEntitlementStatus()
    }

    queue.sync {
      entitlementsByProductId = storage.get(EntitlementsByProductId.self) ?? [:]

      if let activeEntitlements = storage.get(ActiveEntitlements.self) {
        backingActive = activeEntitlements

        // First time
        DispatchQueue.main.async { [weak self] in
          self?.publishedActive = activeEntitlements
          self?.didSetActiveEntitlements = true
        }
      } else {
        backingActive = []
      }

      backingAll = Set(entitlementsByProductId.values.joined())
    }
  }

  // MARK: - Public API

  /// Sets the active entitlements.
  ///
  /// - Parameter entitlements: A `Set` of ``Entitlement`` objects.
  @objc(setActiveEntitlements:)
  public func setActive(_ activeEntitlements: Set<Entitlement>) {
    active = activeEntitlements
  }

  /// Sets the active entitlements.
  ///
  /// - Parameter entitlements: A `Set` of ``Entitlement`` objects.
  @nonobjc
  public func setActive(_ activeEntitlements: [Entitlement]) {
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

  // MARK: - Private API

  @MainActor
  private func listenToEntitlementStatus() {
    $didSetActiveEntitlements.combineLatest($publishedActive)
      .dropFirst()
      .receive(on: DispatchQueue.main)
      .subscribe(Subscribers.Sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] didSet, active in
          guard let self = self else {
            return
          }
          if !didSet {
            self.status = .unknown
          } else if publishedActive.isEmpty {
            self.status = .noActiveEntitlements
          } else {
            self.status = .hasActiveEntitlements(active)
          }

          self.delegateAdapter.entitlementStatusDidChange(to: self.status)
          Task {
            let event = InternalSuperwallPlacement.EntitlementStatusDidChange(status: self.status)
            await Superwall.shared.track(event)
          }
        }
      ))
  }
}
