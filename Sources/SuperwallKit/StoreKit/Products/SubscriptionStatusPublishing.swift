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
/// which dispatches one ``EntitlementsAction``. Once the store is unlocked,
/// `entitlementsDidPublish` gets each change in the order it was applied,
/// emits the status and rebuilds customer info from that change's state.
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

  /// Records the change and works out the merged status in one locked step
  /// of the entitlements store, which reads the test-mode override in that
  /// same step so a stale override can't be published last.
  ///
  /// A developer assignment gets two extra treatments: records identical to a
  /// current grant are stripped, because a developer who reads the published
  /// status and writes it back would otherwise hand the grants back as their
  /// own and clearing them could never revoke; and an `.inactive` assignment
  /// while active grants exist logs a one-time warning, since the status
  /// publishes as active and otherwise looks ignored.
  func publishSubscriptionStatus(_ change: SubscriptionStatusChange) {
    entitlements.publish(change)
  }

  // MARK: - Listening

  func listenToSubscriptionStatus() {
    statusWithGrants
      .removeDuplicates { $0.status.isLogicallyEqual(to: $1.status) }
      .scan((previous: StatusWithGrants?.none, current: StatusWithGrants?.none)) { pair, next in
        // Shift the current value to previous, and set the new one as current.
        (previous: pair.current, current: next)
      }
      .compactMap { pair -> (previous: SubscriptionStatus, current: StatusWithGrants)? in
        guard let previous = pair.previous,
          let current = pair.current else {
          return nil
        }
        return (previous.status, current)
      }
      .receive(on: DispatchQueue.main)
      .subscribe(
        Subscribers.Sink(
          receiveCompletion: { _ in },
          receiveValue: { [weak self] change in
            guard let self = self else {
              return
            }
            let oldStatus = change.previous
            let newStatus = change.current.status

            Task {
              await self.dependencyContainer.delegateAdapter.subscriptionStatusDidChange(
                from: oldStatus, to: newStatus)
              let event = InternalSuperwallEvent.SubscriptionStatusDidChange(
                status: newStatus,
                grantedEntitlements: change.current.granted
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

/// A published status with the granted entitlements it was published with.
struct StatusWithGrants: Equatable {
  let status: SubscriptionStatus
  let granted: Set<Entitlement>
}

// MARK: - EntitlementsPublishing

extension Superwall: EntitlementsPublishing {
  func currentTestModeOverride() -> SubscriptionStatus? {
    if let testModeManager = dependencyContainer.testModeManager,
      testModeManager.isTestMode {
      return testModeManager.overriddenSubscriptionStatus
    }
    return nil
  }

  /// Emits the status and rebuilds customer info from the state this change
  /// left. Changes arrive one at a time, in order, so the last customer info
  /// assigned is always built from the latest change.
  func entitlementsDidPublish(_ publication: EntitlementsPublication) {
    let after = publication.after
    if publication.before.status != after.status {
      emitSubscriptionStatus(after.status, granted: after.granted)
    }

    // Test mode manages its own customer info.
    if dependencyContainer.testModeManager?.isTestMode == true {
      return
    }
    let storage: Storage = dependencyContainer.storage
    if dependencyContainer.makeHasExternalPurchaseController() {
      // The purchase controller's status is the source of the active
      // entitlements, so customer info follows every change.
      customerInfo = CustomerInfo.forExternalPurchaseController(
        storage: storage,
        subscriptionStatus: after.status,
        granted: after.granted
      )
      return
    }
    if case .grantChange = publication.change {
      // Rebuilt from the saved device and web sources, so cleared grants
      // actually disappear.
      let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
      let webCustomerInfo = storage.get(LatestRedeemResponse.self)?.customerInfo ?? .blank()
      customerInfo = deviceCustomerInfo.merging(with: webCustomerInfo, granting: after.granted)
    }
  }
}
