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
/// Every writer ends up in `publishSubscriptionStatus`, which runs under
/// `subscriptionStatusLock` so assignments from different threads can't
/// interleave with the write-back of the merged value.
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
      return dependencyContainer.storage.get(GrantedEntitlements.self) ?? []
    }
    set {
      subscriptionStatusLock.lock()
      defer {
        subscriptionStatusLock.unlock()
      }
      dependencyContainer.storage.save(newValue, forType: GrantedEntitlements.self)
      Logger.debug(
        logLevel: .info,
        scope: .grantedEntitlements,
        message: newValue.isEmpty
          ? "Granted entitlements cleared."
          : "Granted entitlements set: \(newValue.map(\.id).sorted().joined(separator: ", "))"
      )
      publishSubscriptionStatus(assigned: assignedSubscriptionStatus, isDeveloperAssignment: false)
      refreshAutomaticCustomerInfoAfterGrantChange(granted: newValue)
    }
  }

  // MARK: - Assigning

  /// Assigns a new status and publishes the merged result in a single
  /// store, so subscribers never observe the un-merged value.
  ///
  /// SDK writers use this rather than assigning ``subscriptionStatus``: the
  /// public setter has to store the raw value before `didSet` can merge it,
  /// which publishes the raw value first.
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

  /// Records `assigned`, publishes the merged status in a single store,
  /// persists the assigned value, and runs the side effects of a change.
  ///
  /// Takes `subscriptionStatusLock` itself; callers that already hold it
  /// (the ``subscriptionStatus`` observers, the ``grantedEntitlements``
  /// setter) simply recurse. The granted snapshot is read here, under the
  /// lock, so a concurrent grant write can't slip between the read and the
  /// publish.
  ///
  /// `isDeveloperAssignment` is `true` for writes through the public
  /// ``subscriptionStatus`` setter — the only path that warrants warning
  /// about granted entitlements overriding an `.inactive` assignment.
  func publishSubscriptionStatus(
    assigned: SubscriptionStatus,
    isDeveloperAssignment: Bool
  ) {
    subscriptionStatusLock.lock()
    defer {
      subscriptionStatusLock.unlock()
    }
    // Snapshot once: the warning check and the merge both need it.
    let granted = grantedEntitlements

    // The status publishes as active regardless, which otherwise looks
    // like the SDK ignored the assignment.
    if isDeveloperAssignment,
      case .inactive = assigned,
      !granted.isEmpty,
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

    let previouslyAssigned = assignedSubscriptionStatus
    assignedSubscriptionStatus = assigned

    let merged = mergedSubscriptionStatus(assigned: assigned, granted: granted)
    if merged != subscriptionStatus {
      isPublishingSubscriptionStatus = true
      subscriptionStatus = merged
      isPublishingSubscriptionStatus = false
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
    entitlements.subscriptionStatusDidSet(subscriptionStatus)

    // When using an external purchase controller, update CustomerInfo.entitlements
    // to reflect the entitlements from the purchase controller.
    // Skip this in test mode — test mode manages its own CustomerInfo.
    if dependencyContainer.makeHasExternalPurchaseController(),
      dependencyContainer.testModeManager?.isTestMode != true {
      customerInfo = CustomerInfo.forExternalPurchaseController(
        storage: dependencyContainer.storage,
        subscriptionStatus: subscriptionStatus
      )
    }
    publishedSubscriptionStatusSubject.send(subscriptionStatus)
  }

  /// The status the SDK reports for `assigned`: active granted entitlements
  /// merged in, any test-mode override applied, and an empty `.active`
  /// collapsed to `.inactive`.
  private func mergedSubscriptionStatus(
    assigned: SubscriptionStatus,
    granted: Set<Entitlement>
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
    let activeGrants = Set(granted.filter(\.isActive))
    if !activeGrants.isEmpty {
      switch status {
      case .active(let entitlements):
        // mergePrioritized explicitly: plain Set.union dedupes by deep
        // equality, which would keep both records for a shared ID.
        status = .active(
          Entitlement.mergePrioritized(Array(entitlements) + Array(activeGrants))
        )
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
  private func refreshAutomaticCustomerInfoAfterGrantChange(granted: Set<Entitlement>) {
    if dependencyContainer.makeHasExternalPurchaseController() {
      return
    }
    if dependencyContainer.testModeManager?.isTestMode == true {
      return
    }
    let storage: Storage = dependencyContainer.storage
    let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
    let webCustomerInfo = storage.get(LatestRedeemResponse.self)?.customerInfo ?? .blank()
    customerInfo = deviceCustomerInfo.merging(with: webCustomerInfo, granting: granted)
  }

  // MARK: - Listening

  func listenToSubscriptionStatus() {
    // Listens to the published stream rather than $subscriptionStatus so the
    // delegate and the status-change event never see the transient raw
    // value that the public setter stores before merging.
    publishedSubscriptionStatusSubject
      .prepend(subscriptionStatus)
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
