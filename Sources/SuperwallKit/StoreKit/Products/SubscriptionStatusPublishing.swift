//
//  SubscriptionStatusPublishing.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-02.
//

import Combine
import Foundation

/// How ``Superwall/subscriptionStatus`` is produced.
///
/// Two values are involved:
/// - The **assigned** status: what a writer handed the SDK — device + web
///   entitlements on the automatic path, or the developer's own value when
///   using a purchase controller. Kept in `assignedSubscriptionStatus` and
///   persisted.
/// - The **published** status: the assigned status with
///   ``Superwall/grantedEntitlements`` merged in, any test-mode override
///   applied, and an empty `.active` collapsed to `.inactive`. This is what
///   ``Superwall/subscriptionStatus`` holds.
///
/// The assigned value is kept because the published one can't be un-merged:
/// clearing granted entitlements recomputes the published status from it.
///
/// Every writer — the public setter included, via ``PublishedSubscriptionStatus``
/// — ends up in `publishSubscriptionStatus`, the one critical section under
/// `subscriptionStatusLock`. The merged value is stored under the lock and
/// emitted to subscribers after it's released.
extension Superwall {
  // MARK: - Granted entitlements

  /// Entitlements granted by your own backend that Superwall can't observe,
  /// which the SDK merges into ``subscriptionStatus`` alongside device and web
  /// entitlements.
  ///
  /// Use this when access is granted outside of the App Store and the web —
  /// for example, a promotional grant or an account comped by your backend.
  /// Don't use this if you compute the full subscription picture in a
  /// `PurchaseController` — in that case set ``subscriptionStatus`` directly,
  /// otherwise two writers feed one value and the merge will surprise you.
  ///
  /// Each assignment replaces the previous value outright — granting `[a]`
  /// and then `[b]` leaves only `b`. Assign an empty set to revoke.
  ///
  /// - Warning: This persists across app launches, ``reset()``, and
  /// ``identify(userId:options:)``. You must set it again immediately after
  /// calling `identify()` or `reset()` if the new user shouldn't inherit the
  /// previous user's granted entitlements.
  public var grantedEntitlements: Set<Entitlement> {
    get {
      return entitlements.granted
    }
    set {
      entitlements.setGranted(newValue)
      Logger.debug(
        logLevel: .debug,
        scope: .grantedEntitlements,
        message: newValue.isEmpty
          ? "Granted entitlements cleared."
          : "Granted entitlements set: \(newValue.map(\.id).sorted().joined(separator: ", "))"
      )
      publishSubscriptionStatus(assigned: nil, isDeveloperAssignment: false)
      refreshAutomaticCustomerInfoAfterGrantChange()
    }
  }

  // MARK: - Assigning

  /// Assigns a new status and publishes the merged result.
  ///
  /// SDK writers use this rather than assigning ``subscriptionStatus``, which
  /// is the developer's entry point and gets the developer-assignment
  /// treatment described on `publishSubscriptionStatus`.
  func setSubscriptionStatus(assigned status: SubscriptionStatus) {
    publishSubscriptionStatus(assigned: status, isDeveloperAssignment: false)
  }

  /// Merges web entitlements into the device status and assigns the result,
  /// if there's no external purchase controller.
  @MainActor
  func internallySetSubscriptionStatus(
    to status: SubscriptionStatus,
    superwall: Superwall? = nil
  ) {
    if dependencyContainer.makeHasExternalPurchaseController() {
      return
    }
    let activeWebEntitlements = dependencyContainer.entitlementsInfo.web
    let superwall = superwall ?? Superwall.shared
    let deviceAndWebStatus: SubscriptionStatus
    switch status {
    case .active(let entitlements):
      // Use mergePrioritized to intelligently merge device and web entitlements
      // This ensures the highest priority version is kept for each entitlement ID
      let combinedEntitlements = Array(entitlements) + Array(activeWebEntitlements)
      let mergedEntitlements = Entitlement.mergePrioritized(combinedEntitlements)
      deviceAndWebStatus = mergedEntitlements.isEmpty ? .inactive : .active(mergedEntitlements)
    case .inactive:
      deviceAndWebStatus = activeWebEntitlements.isEmpty ? .inactive : .active(activeWebEntitlements)
    case .unknown:
      // Web entitlements deliberately don't promote .unknown to active,
      // unlike granted entitlements (see mergedSubscriptionStatus). This
      // branch only runs without an external purchase controller, where the
      // AutomaticPurchaseController is guaranteed to replace .unknown after
      // loading purchased products — so .unknown is always transient here.
      deviceAndWebStatus = .unknown
    }
    superwall.setSubscriptionStatus(assigned: deviceAndWebStatus)
  }

  // MARK: - Publishing

  /// Records the assigned status, stores the merged status and persists the
  /// assigned value under the lock, then emits the merged status and runs the
  /// remaining side effects outside it.
  ///
  /// Pass `nil` as `assigned` to re-publish from the current assigned status
  /// — after a grant change — which is then read under the lock.
  ///
  /// `isDeveloperAssignment` is `true` for writes through the public
  /// ``subscriptionStatus`` setter, which get two extra treatments: records
  /// identical to a current grant are stripped, because a developer who reads
  /// the published status and writes it back would otherwise hand the grants
  /// back as their own and clearing them could never revoke; and an
  /// `.inactive` assignment while active grants exist logs a one-time
  /// warning, since the status publishes as active and otherwise looks
  /// ignored.
  func publishSubscriptionStatus(
    assigned newAssigned: SubscriptionStatus?,
    isDeveloperAssignment: Bool
  ) {
    subscriptionStatusLock.lock()

    // Snapshot once, under the lock, so a concurrent grant write can't slip
    // between the read and the store. Active grants are merged here so two
    // grants sharing an ID collapse to one record on every path.
    let granted = entitlements.granted
    let activeGrants = Entitlement.mergePrioritized(Array(granted.filter(\.isActive)))

    var assigned = newAssigned ?? assignedSubscriptionStatus
    if isDeveloperAssignment {
      if case .active(let assignedEntitlements) = assigned {
        assigned = .active(assignedEntitlements.subtracting(granted))
      }
      if case .inactive = assigned,
        !activeGrants.isEmpty,
        !hasLoggedGrantedEntitlementsWarning {
        hasLoggedGrantedEntitlementsWarning = true
        Logger.debug(
          logLevel: .warn,
          scope: .grantedEntitlements,
          message: "subscriptionStatus was set to .inactive but grantedEntitlements "
            + "is not empty, so the status remains active. Assigning subscriptionStatus "
            + "doesn't clear granted entitlements — set grantedEntitlements to an empty set to revoke them."
        )
      }
    }

    let previouslyAssigned = assignedSubscriptionStatus
    assignedSubscriptionStatus = assigned

    let merged = mergedSubscriptionStatus(assigned: assigned, activeGrants: activeGrants)
    let statusChanged = merged != subscriptionStatus
    if statusChanged {
      storeMergedSubscriptionStatus(merged)
    }

    // Persist the assigned value, not the merged one: restoring a merged
    // value would bake granted entitlements into the assigned status for
    // good, making them impossible to clear after a relaunch.
    //
    // Saved here rather than in the status listener so that metadata-only
    // updates, which the listener dedupes, still refresh the cache. Identical
    // writes are skipped so they don't re-encode and rewrite the file.
    if previouslyAssigned != assigned {
      dependencyContainer.storage.save(assigned, forType: SubscriptionStatusKey.self)
    }
    subscriptionStatusLock.unlock()

    // Subscribers and customer info observers run outside the lock, so a
    // subscriber that blocks on another thread can't deadlock a writer.
    if statusChanged {
      emitSubscriptionStatus()
    }
    entitlements.subscriptionStatusDidSet(subscriptionStatus)

    // When using an external purchase controller, update CustomerInfo.entitlements
    // to reflect the entitlements from the purchase controller.
    // Skip this in test mode — test mode manages its own CustomerInfo.
    if dependencyContainer.makeHasExternalPurchaseController(),
      dependencyContainer.testModeManager?.isTestMode != true {
      customerInfo = CustomerInfo.forExternalPurchaseController(
        storage: dependencyContainer.storage,
        subscriptionStatus: subscriptionStatus,
        granted: granted
      )
    }
  }

  /// The status the SDK reports for `assigned`: active granted entitlements
  /// merged in, any test-mode override applied, and an empty `.active`
  /// collapsed to `.inactive`.
  private func mergedSubscriptionStatus(
    assigned: SubscriptionStatus,
    activeGrants: Set<Entitlement>
  ) -> SubscriptionStatus {
    if let testModeManager = dependencyContainer.testModeManager,
      testModeManager.isTestMode,
      let override = testModeManager.overriddenSubscriptionStatus {
      return override
    }
    var status = assigned
    // Only active grants merge into the status, mirroring how web
    // entitlements merge (EntitlementsInfo.web filters to active).
    // Inactive grants still reach customerInfo for round-trip visibility.
    if !activeGrants.isEmpty {
      switch status {
      case .active(let entitlements):
        // Set<Entitlement>.union merges by priority, keeping one record per ID.
        status = .active(entitlements.union(activeGrants))
      case .inactive, .unknown:
        // .unknown promotes to active, unlike web entitlements (see
        // internallySetSubscriptionStatus). With an external purchase
        // controller the developer is the only writer of the status, so
        // .unknown can be terminal — without promotion, a developer relying
        // solely on granted entitlements would be locked out forever.
        status = .active(activeGrants)
      }
    }
    // This must run after the granted merge, or a developer-assigned
    // .active([]) would collapse to .inactive before granted is applied.
    if case .active(let entitlements) = status,
      entitlements.isEmpty {
      return .inactive
    }
    return status
  }

  /// Recomputes `customerInfo` on the automatic path after a grant change,
  /// rebuilding from the stored device and web sources so cleared grants
  /// actually disappear. The external purchase controller path is recomputed
  /// inside `publishSubscriptionStatus`; test mode manages its own customer
  /// info.
  private func refreshAutomaticCustomerInfoAfterGrantChange() {
    if dependencyContainer.makeHasExternalPurchaseController() {
      return
    }
    if dependencyContainer.testModeManager?.isTestMode == true {
      return
    }
    let storage: Storage = dependencyContainer.storage
    let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
    let webCustomerInfo = storage.get(LatestRedeemResponse.self)?.customerInfo ?? .blank()
    customerInfo = deviceCustomerInfo.merging(with: webCustomerInfo, granting: entitlements.granted)
  }

  // MARK: - Listening

  func listenToSubscriptionStatus() {
    $subscriptionStatus
      .removeDuplicates { $0.isLogicallyEqual(to: $1) }
      .dropFirst()
      .scan((previous: subscriptionStatus, current: subscriptionStatus)) { previousPair, newStatus in
        // Shift the current value to previous, and set the new status as the current value
        (previous: previousPair.current, current: newStatus)
      }
      .receive(on: DispatchQueue.main)
      .subscribe(
        Subscribers.Sink(
          receiveCompletion: { _ in },
          receiveValue: { [weak self] statusPair in
            guard let self = self else {
              return
            }
            let oldStatus = statusPair.previous
            let newStatus = statusPair.current

            Task {
              await self.dependencyContainer.delegateAdapter.subscriptionStatusDidChange(
                from: oldStatus, to: newStatus)
              let event = InternalSuperwallEvent.SubscriptionStatusDidChange(
                status: newStatus,
                grantedEntitlements: self.grantedEntitlements
              )
              await self.track(event)
            }
            Task {
              let deviceAttributes = await self.dependencyContainer.makeSessionDeviceAttributes()
              let deviceAttributesPlacement = InternalSuperwallEvent.DeviceAttributes(
                deviceAttributes: deviceAttributes)
              await self.track(deviceAttributesPlacement)
            }
          }
        )
      )
  }
}

// MARK: - Property wrapper

/// The property wrapper behind ``Superwall/subscriptionStatus``.
///
/// Every assignment is routed through `publishSubscriptionStatus`, so the
/// stored and published value is always the merged one — subscribers never
/// see the value a writer assigned before granted entitlements and test-mode
/// overrides were applied. The projected value (`$subscriptionStatus`) replays
/// the current value to new subscribers, like `@Published`.
@propertyWrapper
public struct PublishedSubscriptionStatus {
  private var storage: SubscriptionStatus
  private let subject: CurrentValueSubject<SubscriptionStatus, Never>

  public init(wrappedValue: SubscriptionStatus) {
    storage = wrappedValue
    subject = CurrentValueSubject(wrappedValue)
  }

  @available(*, unavailable, message: "Only available on Superwall.")
  public var wrappedValue: SubscriptionStatus {
    get { fatalError("subscriptionStatus is only readable on Superwall.") }
    set { fatalError("\(newValue) can only be assigned on Superwall.") }
  }

  public var projectedValue: AnyPublisher<SubscriptionStatus, Never> {
    return subject.eraseToAnyPublisher()
  }

  public static subscript(
    _enclosingInstance superwall: Superwall,
    wrapped wrappedKeyPath: ReferenceWritableKeyPath<Superwall, SubscriptionStatus>,
    storage storageKeyPath: ReferenceWritableKeyPath<Superwall, PublishedSubscriptionStatus>
  ) -> SubscriptionStatus {
    get {
      return superwall[keyPath: storageKeyPath].storage
    }
    set {
      superwall.publishSubscriptionStatus(assigned: newValue, isDeveloperAssignment: true)
    }
  }

  /// Stores a merged status without emitting it.
  mutating func store(_ merged: SubscriptionStatus) {
    storage = merged
  }

  /// Emits a stored status to subscribers.
  func emit(_ status: SubscriptionStatus) {
    subject.send(status)
  }
}
