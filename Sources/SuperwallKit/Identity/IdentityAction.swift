//
//  IdentityAction.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

typealias IdentityStore = StateStore<IdentityContext, IdentityState>

/// Everything identity actions need. ``IdentityManager`` provides it in the
/// SDK, and tests provide a fake.
protocol IdentityContext: AnyObject {
  var store: IdentityStore { get }

  /// Waits for the config. Returns the seed derived from `userId` if the
  /// config enables user id seeds, or `nil` if it doesn't or never arrives.
  func userIdSeed(for userId: String) async -> Int?

  /// Fetches the user's assignments once the config has arrived.
  func fetchAssignments() async

  /// Redeems any web entitlement codes the device already has.
  func redeemExistingWebEntitlements() async

  /// The attributes a new user keeps across a reset, such as install-scoped
  /// attribution. Called with the identity unlocked; changes nothing.
  func attributesKeptAcrossReset() -> [String: Any?]

  /// Resets the rest of the SDK for the new user, once the identity has
  /// changed. Called with the identity unlocked, while it isn't ready.
  /// Doesn't change the identity.
  func resetRestOfSDK()

  func trackIdentityAlias()
  func trackUserAttributes(_ attributes: [String: Any])
  func notifyUserChange(_ attributes: [String: Any])

  /// Writes every identity field to storage.
  func persistIdentity(_ state: IdentityState)

  /// Starts async work, such as waiting for the config, outside the store.
  func sideEffect(_ work: @escaping () async -> Void)
}

extension IdentityContext {
  var state: IdentityState {
    store.state
  }

  func update(_ update: IdentityUpdate) {
    store.update(update)
  }

  /// Runs `action` before returning, so a read straight after sees it.
  func dispatch(_ action: IdentityAction) {
    store.dispatch(action, in: self)
  }
}

/// The changes to the identity. Each runs with the identity store locked, so
/// none of them waits on anything: the config and assignments are waited for
/// in side effects, tracked as pending work in the state, and resetting the
/// rest of the SDK runs once the store is unlocked.
enum IdentityAction: StoreAction {
  /// Logs in as `userId`, first replacing another logged in user with a new
  /// anonymous one. `keptAttributes` are those the new user keeps across that
  /// reset, gathered beforehand, or `nil` if no reset was expected.
  case identify(userId: String, restoreAssignments: Bool, keptAttributes: [String: Any?]?)
  /// Applies the seed for an identify's user once the config has said
  /// whether to derive it from the user id.
  case resolveSeed(IdentifyOperation, seed: Int?)
  /// Merges attributes into the user's attributes.
  case mergeAttributes([String: Any?], shouldTrack: Bool, shouldNotify: Bool)
  /// Replaces the user with a new anonymous one, who keeps `keptAttributes`.
  case reset(keptAttributes: [String: Any?])
  /// Writes the current identity to storage, for after the storage has been
  /// wiped.
  case persist

  func execute(in context: IdentityContext) {
    switch self {
    case let .identify(userId, restoreAssignments, keptAttributes):
      identify(
        userId: userId,
        restoreAssignments: restoreAssignments,
        keptAttributes: keptAttributes,
        in: context
      )
    case let .resolveSeed(operation, seed):
      let seedBefore = context.state.seed
      context.update(.resolveSeed(operation, seed: seed))
      if context.state.seed != seedBefore {
        context.trackUserAttributes(context.state.userAttributes)
      }
    case let .mergeAttributes(attributes, shouldTrack, shouldNotify):
      context.update(.mergeAttributes(attributes))
      let merged = context.state.userAttributes
      if shouldTrack {
        context.trackUserAttributes(merged)
      }
      if shouldNotify {
        context.notifyUserChange(merged)
      }
    case .reset(let keptAttributes):
      replaceUser(keptAttributes: keptAttributes, in: context)
      context.update(.established)
      context.trackUserAttributes(context.state.userAttributes)
    case .persist:
      context.persistIdentity(context.state)
    }
  }

  private func identify(
    userId: String,
    restoreAssignments: Bool,
    keptAttributes: [String: Any?]?,
    in context: IdentityContext
  ) {
    guard userId != context.state.appUserId else {
      return
    }

    let operation = IdentifyOperation(userId: userId)
    context.update(.begin(.seed(operation)))
    if restoreAssignments {
      context.update(.begin(.assignments(operation)))
    }

    if context.state.appUserId != nil {
      replaceUser(keptAttributes: keptAttributes, in: context)
    }

    context.update(.identify(operation))
    context.persistIdentity(context.state)
    context.update(.established)

    context.trackIdentityAlias()
    context.trackUserAttributes(context.state.userAttributes)

    // Started once the store is unlocked, after any reset above has wiped
    // the old user's storage, so what they save isn't wiped with it.
    context.store.deferUntilUnlocked {
      startSideEffects(
        of: operation,
        restoreAssignments: restoreAssignments,
        in: context
      )
    }
  }

  private func startSideEffects(
    of operation: IdentifyOperation,
    restoreAssignments: Bool,
    in context: IdentityContext
  ) {
    context.sideEffect { [weak context] in
      guard let context = context else {
        return
      }
      let seed = await context.userIdSeed(for: operation.userId)
      context.dispatch(.resolveSeed(operation, seed: seed))
    }

    context.sideEffect { [weak context] in
      await context?.redeemExistingWebEntitlements()
    }

    context.sideEffect { [weak context] in
      await context?.fetchAssignments()
      if restoreAssignments {
        context?.update(.end(.assignments(operation)))
      }
    }
  }

  /// Replaces the user with a new anonymous one who keeps `keptAttributes`,
  /// then, once the store is unlocked, resets the rest of the SDK. The
  /// identity isn't ready until that has finished.
  ///
  /// `keptAttributes` is `nil` when another thread changed the user between
  /// the caller deciding no reset was needed and this action running. Then
  /// they're gathered once the store is unlocked.
  private func replaceUser(
    keptAttributes: [String: Any?]?,
    in context: IdentityContext
  ) {
    let resetId = UUID()
    context.update(.begin(.reset(resetId)))
    context.update(
      .reset(
        aliasId: IdentityLogic.generateAlias(),
        seed: IdentityLogic.generateSeed()
      )
    )
    if let keptAttributes = keptAttributes {
      context.update(.mergeAttributes(keptAttributes))
    }

    // Runs before the dispatch returns, so holding the context is fine.
    context.store.deferUntilUnlocked {
      if keptAttributes == nil {
        context.dispatch(
          .mergeAttributes(
            context.attributesKeptAcrossReset(),
            shouldTrack: true,
            shouldNotify: false
          )
        )
      }
      context.resetRestOfSDK()
      // The reset wipes the user's storage, identity included.
      context.dispatch(.persist)
      context.update(.end(.reset(resetId)))
    }
  }
}

extension IdentityAction: CustomStringConvertible {
  /// Leaves out user ids and attribute values, which can be personal data.
  var description: String {
    switch self {
    case let .identify(_, restoreAssignments, keptAttributes):
      return "identify(restoreAssignments: \(restoreAssignments), "
        + "keptAttributes: \(keptAttributes?.keys.sorted().description ?? "nil"))"
    case let .resolveSeed(_, seed):
      return "resolveSeed(seed: \(seed.map(String.init) ?? "nil"))"
    case let .mergeAttributes(attributes, shouldTrack, shouldNotify):
      return "mergeAttributes(keys: \(attributes.keys.sorted()), "
        + "shouldTrack: \(shouldTrack), shouldNotify: \(shouldNotify))"
    case .reset(let keptAttributes):
      return "reset(keptAttributes: \(keptAttributes.keys.sorted()))"
    case .persist:
      return "persist"
    }
  }
}

/// Observers that keep storage and readiness in step with the identity.
enum IdentityObservers {
  /// Saves identity fields that an update changed, and reports readiness
  /// whenever it changes.
  ///
  /// `persist` runs with the store locked, one update at a time, in the order
  /// the updates are applied, so an older update can't save over a newer one.
  /// It mustn't wait on anything.
  ///
  /// `readinessChanged` runs once the store is unlocked, so it can call
  /// anything, in the order the changes were applied. While another thread
  /// is reporting readiness, that thread reports this change too, after the
  /// ones before it.
  static func install(
    on store: IdentityStore,
    persist: @escaping (_ before: IdentityState, _ after: IdentityState) -> Void,
    readinessChanged: @escaping (Bool) -> Void
  ) {
    let readiness = OrderedDelivery(readinessChanged)
    var lastReadiness = store.state.isReady
    store.observe { [weak store] before, after in
      persist(before, after)
      if after.isReady != lastReadiness {
        lastReadiness = after.isReady
        readiness.add(after.isReady)
        store?.deferUntilUnlocked {
          readiness.deliver()
        }
      }
    }
  }
}
