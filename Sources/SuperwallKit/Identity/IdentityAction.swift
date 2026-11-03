//
//  IdentityAction.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

typealias IdentityStore = SequentialStore<IdentityContext, IdentityState>

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

  /// Resets the rest of the SDK for a new user. Called from inside the
  /// identify action, before the new user id is set, so it must not wait on
  /// the identity store.
  func resetForNewUser()

  func trackIdentityAlias()
  func trackUserAttributes(_ attributes: [String: Any])
  func notifyUserChange(_ attributes: [String: Any])

  /// Writes every identity field to storage.
  func persistIdentity(_ state: IdentityState)

  /// Starts work that runs outside the store's queue, so that waiting on it
  /// doesn't hold up later identity actions.
  func sideEffect(_ work: @escaping () async -> Void)
}

extension IdentityContext {
  var state: IdentityState {
    store.state
  }

  func update(_ update: IdentityUpdate) {
    store.update(update)
  }

  /// Runs `action`, normally before returning so that reads on this thread
  /// see it. From inside another identity action, it runs once that one
  /// finishes. See ``SequentialStore/dispatch(_:in:)``.
  func dispatch(_ action: IdentityAction) {
    store.dispatch(action, in: self)
  }
}

/// The changes to the identity. None of them wait on anything: the config
/// and assignments are waited for in side effects, tracked as pending work
/// in the state. So they're dispatched synchronously, one at a time, and a
/// read straight after a change normally sees it, as callers of the public
/// identity API expect.
enum IdentityAction: SyncStoreAction {
  /// Logs in as `userId`, resetting first if another user is logged in.
  case identify(userId: String, restoreAssignments: Bool)
  /// Applies the seed for `userId` once the config has said whether to
  /// derive it from the user id.
  case resolveSeed(userId: String, seed: Int?)
  /// Merges attributes into the user's attributes.
  case mergeAttributes([String: Any?], shouldTrack: Bool, shouldNotify: Bool)
  /// Replaces the user with a new anonymous one.
  case reset
  /// Writes the current identity to storage, for after the storage has been
  /// wiped.
  case persist

  func execute(in context: IdentityContext) {
    switch self {
    case let .identify(userId, restoreAssignments):
      identify(userId: userId, restoreAssignments: restoreAssignments, in: context)
    case let .resolveSeed(userId, seed):
      let seedBefore = context.state.seed
      context.update(.resolveSeed(userId: userId, seed: seed))
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
    case .reset:
      context.update(
        .reset(
          aliasId: IdentityLogic.generateAlias(),
          seed: IdentityLogic.generateSeed()
        )
      )
      context.update(.established)
      context.trackUserAttributes(context.state.userAttributes)
    case .persist:
      context.persistIdentity(context.state)
    }
  }

  private func identify(
    userId: String,
    restoreAssignments: Bool,
    in context: IdentityContext
  ) {
    guard userId != context.state.appUserId else {
      return
    }

    if context.state.appUserId != nil {
      // Resets this store inline through `IdentityManager.reset(duringIdentify:)`
      // and wipes the user's storage, so it has to come before the new id
      // is set and saved. Identity changes it makes run after this one.
      context.resetForNewUser()
    }

    context.update(.identify(userId: userId))
    if restoreAssignments {
      context.update(.begin(.assignments))
    }
    // The reset above may have wiped every identity field from storage, not
    // just the ones this identify changed.
    context.persistIdentity(context.state)
    context.update(.established)

    context.trackIdentityAlias()
    context.trackUserAttributes(context.state.userAttributes)

    context.sideEffect { [weak context] in
      guard let context = context else {
        return
      }
      let seed = await context.userIdSeed(for: userId)
      context.dispatch(.resolveSeed(userId: userId, seed: seed))
    }

    context.sideEffect { [weak context] in
      await context?.redeemExistingWebEntitlements()
    }

    context.sideEffect { [weak context] in
      await context?.fetchAssignments()
      if restoreAssignments {
        context?.update(.end(.assignments))
      }
    }
  }
}

extension IdentityAction: CustomStringConvertible {
  /// Leaves out attribute values, which can be personal data.
  var description: String {
    switch self {
    case let .identify(_, restoreAssignments):
      return "identify(restoreAssignments: \(restoreAssignments))"
    case let .resolveSeed(_, seed):
      return "resolveSeed(seed: \(seed.map(String.init) ?? "nil"))"
    case let .mergeAttributes(attributes, shouldTrack, shouldNotify):
      return "mergeAttributes(keys: \(attributes.keys.sorted()), "
        + "shouldTrack: \(shouldTrack), shouldNotify: \(shouldNotify))"
    case .reset:
      return "reset"
    case .persist:
      return "persist"
    }
  }
}

/// Interceptors that keep the identity's observers in step with the store.
enum IdentityInterceptors {
  /// Saves identity fields that an update changed, and reports readiness
  /// whenever it might have changed.
  static func installObservers(
    on store: IdentityStore,
    persist: @escaping (_ before: IdentityState, _ after: IdentityState) -> Void,
    readinessChanged: @escaping (Bool) -> Void
  ) {
    let readinessLock = NSRecursiveLock()
    var lastReadiness = store.state.isReady

    store.onUpdate { _, next in
      let before = store.state
      next()
      let after = store.state
      persist(before, after)

      // Read and report under one lock so concurrent updates can't report
      // readiness out of order.
      readinessLock.lock()
      let ready = store.state.isReady
      if ready != lastReadiness {
        lastReadiness = ready
        readinessChanged(ready)
      }
      readinessLock.unlock()
    }
  }
}
