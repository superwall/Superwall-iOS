//
//  EntitlementsState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

/// Holds ``EntitlementsState``. Changed by ``EntitlementsAction``s, whose
/// side effects are the methods of ``EntitlementsContext``.
typealias EntitlementsStore = StateStore<EntitlementsContext, EntitlementsState>

/// What the SDK knows about the user's entitlements and subscription status.
/// Changed only by ``EntitlementsUpdate`` reducers on its store.
///
/// The **assigned** status is what a writer handed the SDK: device and web
/// entitlements on the automatic path, or the developer's own value when using
/// a purchase controller. The published ``status`` is worked out from it, the
/// granted entitlements and the test-mode override on every read, so clearing
/// granted entitlements removes them again and the published status can never
/// disagree with what it's made from.
struct EntitlementsState: Equatable {
  /// The entitlements that belong to each product ID, from the config.
  var entitlementsByProductId: [String: Set<Entitlement>] = [:]
  /// The entitlements set through ``Superwall/grantedEntitlements``.
  var granted: Set<Entitlement> = []
  var assignedStatus: SubscriptionStatus = .unknown
  /// The test-mode override as of the last status change.
  var testMode: TestModeOverride = .off
  var grantWarning: GrantWarning = .notDue

  /// ``Superwall/subscriptionStatus``: the test-mode override if there is
  /// one, otherwise the assigned status with active grants merged in and an
  /// empty `.active` turned into `.inactive`.
  var status: SubscriptionStatus {
    switch testMode {
    case .overriding(let status):
      return status
    case .off:
      return Self.merged(assigned: assignedStatus, granted: granted)
    }
  }

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

  private static func merged(
    assigned: SubscriptionStatus,
    granted: Set<Entitlement>
  ) -> SubscriptionStatus {
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

/// Whether test mode replaces the published status.
enum TestModeOverride: Equatable {
  case off
  case overriding(SubscriptionStatus)

  init(_ status: SubscriptionStatus?) {
    if let status = status {
      self = .overriding(status)
    } else {
      self = .off
    }
  }
}

/// The once-per-session warning that an `.inactive` assignment stays active
/// because of granted entitlements.
enum GrantWarning: Equatable {
  case notDue
  case logged
}

/// The ways ``EntitlementsState`` can change.
enum EntitlementsUpdate: Reducer {
  /// The entitlements saved by an earlier launch were read from storage.
  case savedEntitlementsLoaded(granted: Set<Entitlement>, byProductId: [String: Set<Entitlement>])
  /// The config's product entitlements arrived, replacing the old ones.
  case productEntitlementsReceived([String: Set<Entitlement>])
  /// The developer assigned ``Superwall/subscriptionStatus``.
  case developerAssignedStatus(SubscriptionStatus, testMode: TestModeOverride)
  /// The SDK assigned a status it worked out itself.
  case sdkAssignedStatus(SubscriptionStatus, testMode: TestModeOverride)
  /// ``Superwall/grantedEntitlements`` changed.
  case grantsChanged(Set<Entitlement>, testMode: TestModeOverride)

  func reduce(_ state: EntitlementsState) -> EntitlementsState {
    var state = state
    switch self {
    case let .savedEntitlementsLoaded(granted, byProductId):
      state.granted = granted
      state.entitlementsByProductId = byProductId
    case .productEntitlementsReceived(let entitlementsByProductId):
      state.entitlementsByProductId = entitlementsByProductId
    case let .developerAssignedStatus(status, testMode):
      state.testMode = testMode
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
        state.grantWarning = .logged
      }
    case let .sdkAssignedStatus(status, testMode):
      state.testMode = testMode
      state.assignedStatus = status
    case let .grantsChanged(granted, testMode):
      state.testMode = testMode
      state.granted = granted
    }
    return state
  }
}

/// One status change, handed to ``EntitlementsPublishing`` once the store is
/// unlocked, in the order the changes were applied.
struct EntitlementsPublication {
  let change: SubscriptionStatusChange
  let before: EntitlementsState
  let after: EntitlementsState
}

/// Everything an ``EntitlementsAction`` can cause. Methods that run with the
/// store locked must not wait on another thread.
protocol EntitlementsContext: AnyObject {
  var store: EntitlementsStore { get }

  /// The status test mode wants published, if any. Read with the store
  /// locked, so the writer that publishes last also read it last.
  func currentTestModeOverride() -> SubscriptionStatus?

  func saveProductMap(_ entitlementsByProductId: [String: Set<Entitlement>])
  func saveGranted(_ granted: Set<Entitlement>)
  /// Saves the assigned status, not the published one: restoring a published
  /// value would make granted entitlements part of the assigned status for
  /// good, so they couldn't be cleared after a relaunch.
  func saveAssignedStatus(_ status: SubscriptionStatus)

  /// Runs once the store is unlocked.
  func logGrantWarning()

  /// Queues `publication` behind the ones before it. Doesn't wait.
  func queuePublication(_ publication: EntitlementsPublication)
  /// Hands the queued publications over in order. Runs once the store is
  /// unlocked.
  func deliverPublications()
}

/// The changes to the entitlements. Each runs with the store locked and
/// returns the state it left.
enum EntitlementsAction: StoreAction {
  case changeStatus(SubscriptionStatusChange)
  case receiveProductEntitlements([String: Set<Entitlement>])

  @discardableResult
  func execute(in context: EntitlementsContext) -> EntitlementsState {
    let store = context.store
    let before = store.state
    switch self {
    case .changeStatus(let change):
      let testMode = TestModeOverride(context.currentTestModeOverride())
      switch change {
      case .developerAssignment(let status):
        store.update(EntitlementsUpdate.developerAssignedStatus(status, testMode: testMode))
      case .sdkAssignment(let status):
        store.update(EntitlementsUpdate.sdkAssignedStatus(status, testMode: testMode))
      case .grantChange(let granted):
        store.update(EntitlementsUpdate.grantsChanged(granted, testMode: testMode))
      }
      let after = store.state
      if before.granted != after.granted {
        context.saveGranted(after.granted)
      }
      if before.assignedStatus != after.assignedStatus {
        context.saveAssignedStatus(after.assignedStatus)
      }
      if before.grantWarning == .notDue,
        after.grantWarning == .logged {
        store.deferUntilUnlocked {
          context.logGrantWarning()
        }
      }
      context.queuePublication(
        EntitlementsPublication(change: change, before: before, after: after)
      )
      store.deferUntilUnlocked {
        context.deliverPublications()
      }
      return after
    case .receiveProductEntitlements(let entitlementsByProductId):
      store.update(EntitlementsUpdate.productEntitlementsReceived(entitlementsByProductId))
      let after = store.state
      if before.entitlementsByProductId != after.entitlementsByProductId {
        context.saveProductMap(after.entitlementsByProductId)
      }
      return after
    }
  }
}
