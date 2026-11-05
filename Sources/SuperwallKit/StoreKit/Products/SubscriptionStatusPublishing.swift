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
/// Both values and the granted entitlements live in the entitlements store
/// (``EntitlementsState``). Every writer — the public setter included, via
/// ``PublishedSubscriptionStatus`` — ends up in `publishSubscriptionStatus`,
/// which changes them in one reducer. The store's observers save the
/// assigned value and emit the merged one to subscribers once the store is
/// unlocked, in the order the changes were applied.
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
      Logger.debug(
        logLevel: .debug,
        scope: .grantedEntitlements,
        message: newValue.isEmpty
          ? "Granted entitlements cleared."
          : "Granted entitlements set: \(newValue.map(\.id).sorted().joined(separator: ", "))"
      )
      publishSubscriptionStatus(.grantChange(newValue))
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
    publishSubscriptionStatus(.sdkAssignment(status))
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
      // Neither web nor granted entitlements turn .unknown into a decision
      // (see EntitlementsUpdate.mergedStatus). This branch only runs without an
      // external purchase controller, where the AutomaticPurchaseController
      // replaces .unknown after loading purchased products, so it's always
      // transient here anyway.
      deviceAndWebStatus = .unknown
    }
    superwall.setSubscriptionStatus(assigned: deviceAndWebStatus)
  }

  // MARK: - Publishing

  /// Records the change and works out the merged status in one update of the
  /// entitlements store, which saves the assigned value and emits the merged
  /// one once it's unlocked.
  ///
  /// A developer assignment gets two extra treatments: records identical to a
  /// current grant are stripped, because a developer who reads the published
  /// status and writes it back would otherwise hand the grants back as their
  /// own and clearing them could never revoke; and an `.inactive` assignment
  /// while active grants exist logs a one-time warning, since the status
  /// publishes as active and otherwise looks ignored.
  func publishSubscriptionStatus(_ change: SubscriptionStatusChange) {
    var testModeOverride: SubscriptionStatus?
    if let testModeManager = dependencyContainer.testModeManager,
      testModeManager.isTestMode {
      testModeOverride = testModeManager.overriddenSubscriptionStatus
    }
    entitlements.publish(change, testModeOverride: testModeOverride)

    // When using an external purchase controller, update CustomerInfo.entitlements
    // to reflect the entitlements from the purchase controller.
    // Skip this in test mode — test mode manages its own CustomerInfo.
    if dependencyContainer.makeHasExternalPurchaseController(),
      dependencyContainer.testModeManager?.isTestMode != true {
      refreshExternalControllerCustomerInfo()
    }
  }

  /// A consistent pair of the published status and the granted set.
  private struct PublishedSnapshot: Equatable {
    let status: SubscriptionStatus
    let granted: Set<Entitlement>
  }

  private func publishedSnapshot() -> PublishedSnapshot {
    let state = entitlements.store.state
    return PublishedSnapshot(status: state.status, granted: state.granted)
  }

  /// Recomputes `customerInfo` for the external purchase controller path
  /// outside the lock, so `$customerInfo` subscribers don't run inside the
  /// SDK's critical section.
  ///
  /// It's built from a consistent snapshot and dropped if a concurrent
  /// publish moved either input while it ran: that publish runs its own
  /// refresh with the newer values, so assigning ours would put the older
  /// customer info last. Uncontended — the normal case, and the only one a
  /// synchronous read after a status write depends on — the snapshot is
  /// unchanged and the value is assigned before this returns.
  private func refreshExternalControllerCustomerInfo() {
    let snapshot = publishedSnapshot()
    let info = CustomerInfo.forExternalPurchaseController(
      storage: dependencyContainer.storage,
      subscriptionStatus: snapshot.status,
      granted: snapshot.granted
    )
    if publishedSnapshot() == snapshot {
      customerInfo = info
    }
  }

  /// Recomputes `customerInfo` on the automatic path after a grant change,
  /// rebuilding from the stored device and web sources so cleared grants
  /// actually disappear. The external purchase controller path is recomputed
  /// by `publishSubscriptionStatus`; test mode manages its own customer
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
