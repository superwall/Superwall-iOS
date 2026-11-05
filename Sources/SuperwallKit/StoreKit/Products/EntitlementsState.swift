//
//  EntitlementsState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

/// Holds ``EntitlementsState``. Most changes are a single
/// ``EntitlementsUpdate``; saving and publishing are done by observers.
typealias EntitlementsStore = StateStore<EntitlementsInfo, EntitlementsState>

/// Publishes a subscription status change, reading the test-mode override
/// with the store locked.
///
/// Reading it before taking the lock would let a writer read an override,
/// lose the race for the lock to a writer that read a newer one, and then
/// publish the older override last. Read with the lock held, the writer that
/// applies last also read last.
struct PublishSubscriptionStatus: StoreAction {
  let change: SubscriptionStatusChange
  /// Returns the test-mode override, if test mode has one. Runs with the
  /// store locked, so it must only read values, never wait.
  let testModeOverride: () -> SubscriptionStatus?

  func execute(in context: EntitlementsInfo) {
    context.store.update(
      EntitlementsUpdate.publish(change, testModeOverride: testModeOverride())
    )
  }
}

/// What the SDK knows about the user's entitlements and subscription status.
/// Changed only by ``EntitlementsUpdate`` reducers on its store.
///
/// Two statuses are kept:
/// - The **assigned** status: what a writer handed the SDK. Device and web
///   entitlements on the automatic path, or the developer's own value when
///   using a purchase controller. It's saved, and the published status is
///   always worked out from it, so clearing granted entitlements can remove
///   them again.
/// - The **published** status: the assigned status with active granted
///   entitlements merged in, any test-mode override applied, and an empty
///   `.active` turned into `.inactive`. This is ``Superwall/subscriptionStatus``.
///
/// ``active``, ``all`` and ``inactive`` are worked out on each read rather
/// than stored, so they always match the status and product map they come
/// from.
struct EntitlementsState: Equatable {
  /// The entitlements that belong to each product ID, from the config.
  var entitlementsByProductId: [String: Set<Entitlement>] = [:]
  /// The entitlements set through ``Superwall/grantedEntitlements``.
  var granted: Set<Entitlement> = []
  var assignedStatus: SubscriptionStatus = .unknown
  var status: SubscriptionStatus = .unknown
  /// Whether the warning about granted entitlements keeping an `.inactive`
  /// assignment active is due or has been logged. It's logged once per
  /// session.
  var hasGrantedEntitlementsWarning = false

  /// All entitlements from the config, whether active or not.
  var all: Set<Entitlement> {
    Set(entitlementsByProductId.values.joined())
  }

  /// The entitlements of the published status.
  var active: Set<Entitlement> {
    if case .active(let entitlements) = status {
      return entitlements
    }
    return []
  }

  var inactive: Set<Entitlement> {
    all.subtracting(active)
  }

  func byProductId(_ productId: String) -> Set<Entitlement> {
    entitlementsByProductId[productId] ?? []
  }

  func byProductIds(_ productIds: Set<String>) -> Set<Entitlement> {
    var entitlements: Set<Entitlement> = []
    for productId in productIds {
      if let productEntitlements = entitlementsByProductId[productId] {
        entitlements.formUnion(productEntitlements)
      }
    }
    return entitlements
  }
}

/// The ways ``EntitlementsState`` can change.
enum EntitlementsUpdate: Reducer {
  /// Replaces the entitlements of every product.
  case productEntitlements([String: Set<Entitlement>])
  /// Records a new assigned status, or new granted entitlements, and works
  /// out the published status from them. `testModeOverride`, when set,
  /// replaces the published status.
  case publish(SubscriptionStatusChange, testModeOverride: SubscriptionStatus?)

  func reduce(_ state: EntitlementsState) -> EntitlementsState {
    var state = state
    switch self {
    case .productEntitlements(let entitlementsByProductId):
      state.entitlementsByProductId = entitlementsByProductId
    case let .publish(change, testModeOverride):
      Self.publish(change, testModeOverride: testModeOverride, into: &state)
    }
    return state
  }

  private static func publish(
    _ change: SubscriptionStatusChange,
    testModeOverride: SubscriptionStatus?,
    into state: inout EntitlementsState
  ) {
    switch change {
    case .developerAssignment(let status):
      state.assignedStatus = status
      // A developer who reads the published status and writes it back would
      // otherwise hand the grants back as their own, and clearing them could
      // never revoke them. Compared ignoring product IDs: the merge unions
      // those across a shared ID, so a grant that won a collision comes back
      // carrying the loser's product IDs.
      if case .active(let assigned) = status {
        state.assignedStatus = .active(
          assigned.filter { record in
            !state.granted.contains { $0.isEqualIgnoringProductIds(to: record) }
          }
        )
      }
      // The status publishes as active, so the assignment would otherwise
      // look ignored.
      if case .inactive = status,
        state.granted.contains(where: \.isActive) {
        state.hasGrantedEntitlementsWarning = true
      }
    case .sdkAssignment(let status):
      state.assignedStatus = status
    case .grantChange(let granted):
      state.granted = granted
    }

    state.status = mergedStatus(
      assigned: state.assignedStatus,
      granted: state.granted,
      testModeOverride: testModeOverride
    )
  }

  /// The status the SDK reports for `assigned`.
  static func mergedStatus(
    assigned: SubscriptionStatus,
    granted: Set<Entitlement>,
    testModeOverride: SubscriptionStatus?
  ) -> SubscriptionStatus {
    if let testModeOverride = testModeOverride {
      return testModeOverride
    }
    // Only active grants merge in, as with web entitlements. Inactive grants
    // still reach customer info. Merged first so two grants sharing an ID
    // become one record.
    let activeGrants = Entitlement.mergePrioritized(Array(granted.filter(\.isActive)))
    var status = assigned
    if !activeGrants.isEmpty {
      switch status {
      case .active(let entitlements):
        // Set<Entitlement>.union merges by priority, keeping one record per ID.
        status = .active(entitlements.union(activeGrants))
      case .inactive:
        status = .active(activeGrants)
      case .unknown:
        // `.unknown` means the status hasn't been worked out yet, and grants
        // don't decide it. Reporting active here would open the paywall
        // presentation gate before a purchase controller has answered.
        break
      }
    }
    // After the grant merge, or a developer-assigned `.active([])` would turn
    // `.inactive` before the grants were merged in.
    if case .active(let entitlements) = status,
      entitlements.isEmpty {
      return .inactive
    }
    return status
  }
}
