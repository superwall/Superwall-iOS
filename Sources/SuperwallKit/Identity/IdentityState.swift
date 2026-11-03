//
//  IdentityState.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

/// The user's identity: who they are, the attributes they carry, and what's
/// still being resolved before paywalls can be shown to them.
///
/// Changed only by ``IdentityUpdate`` reducers on ``IdentityManager``'s store.
struct IdentityState {
  /// Work that has to finish before the identity is ready.
  enum Pending: Hashable {
    /// `configure()` is running, possibly waiting for assignments.
    case configuration
    /// The seed for this newly identified user is waiting on the config.
    /// Keyed by user id so a lookup that's overtaken by a reset or another
    /// identify still resolves its own entry.
    case seed(String)
    /// Assignments are being restored before the identity is ready.
    case assignments
  }

  enum Keys {
    static let appUserId = "appUserId"
    static let aliasId = "aliasId"
    static let seed = "seed"
  }

  var appUserId: String?
  var aliasId: String
  var seed: Int
  var userAttributes: [String: Any]
  var pending: Set<Pending>
  /// Whether `configure()`, `identify(userId:)` or `reset()` has finished at
  /// least once. Until then the identity hasn't been established.
  var hasResolved: Bool
  let appInstalledAtString: String

  init(
    appUserId: String? = nil,
    aliasId: String,
    seed: Int,
    userAttributes: [String: Any] = [:],
    pending: Set<Pending> = [],
    hasResolved: Bool = false,
    appInstalledAtString: String
  ) {
    self.appUserId = appUserId
    self.aliasId = aliasId
    self.seed = seed
    self.userAttributes = userAttributes
    self.pending = pending
    self.hasResolved = hasResolved
    self.appInstalledAtString = appInstalledAtString
  }

  /// Whether paywalls can be shown to this identity: it has been established
  /// once, and nothing that changes it is in progress.
  var isReady: Bool {
    hasResolved && pending.isEmpty
  }

  /// The app user id, or the alias for an anonymous user.
  var userId: String {
    appUserId ?? aliasId
  }

  var isLoggedIn: Bool {
    appUserId != nil
  }

  /// Merges `attributes` into ``userAttributes``.
  func merging(_ attributes: [String: Any?]) -> IdentityState {
    var state = self
    state.userAttributes = IdentityLogic.mergeAttributes(
      attributes,
      with: userAttributes,
      appInstalledAtString: appInstalledAtString
    )
    return state
  }

  /// Merges the current ids into ``userAttributes``.
  func mergingIds() -> IdentityState {
    var ids: [String: Any?] = [
      Keys.aliasId: aliasId,
      Keys.seed: seed
    ]
    if let appUserId = appUserId {
      ids[Keys.appUserId] = appUserId
    }
    return merging(ids)
  }
}

/// The ways ``IdentityState`` can change. Each is a pure function of the state.
enum IdentityUpdate: Reducer {
  /// Adds work that has to finish before the identity is ready.
  case begin(IdentityState.Pending)
  /// Marks work as finished. Does nothing if it wasn't pending. Finishing
  /// `configure()` establishes the identity.
  case end(IdentityState.Pending)
  /// A configure, identify or reset has finished, so the identity is
  /// established.
  case established
  /// Logs in as `userId`, keeping the alias and seed. The seed is pending
  /// until the config says whether to derive it from the user id.
  case identify(userId: String)
  /// Resolves the pending seed for `userId`. Sets `seed` if `userId` is
  /// still the logged in user, otherwise only resolves it.
  case resolveSeed(userId: String, seed: Int?)
  /// Merges attributes into the user's attributes.
  case mergeAttributes([String: Any?])
  /// Replaces the user with a new anonymous one. Keeps any pending work.
  case reset(aliasId: String, seed: Int)

  func reduce(_ state: IdentityState) -> IdentityState {
    var state = state
    switch self {
    case .begin(let item):
      state.pending.insert(item)
      return state
    case .end(let item):
      state.pending.remove(item)
      if item == .configuration {
        state.hasResolved = true
      }
      return state
    case .established:
      state.hasResolved = true
      return state
    case .identify(let userId):
      guard userId != state.appUserId else {
        return state
      }
      state.appUserId = userId
      state.pending.insert(.seed(userId))
      return state.mergingIds()
    case let .resolveSeed(userId, seed):
      state.pending.remove(.seed(userId))
      guard
        let seed = seed,
        userId == state.appUserId,
        seed != state.seed
      else {
        return state
      }
      state.seed = seed
      return state.mergingIds()
    case .mergeAttributes(let attributes):
      return state.merging(attributes)
    case let .reset(aliasId, seed):
      return IdentityState(
        aliasId: aliasId,
        seed: seed,
        pending: state.pending,
        hasResolved: state.hasResolved,
        appInstalledAtString: state.appInstalledAtString
      )
      .mergingIds()
    }
  }
}

extension IdentityLogic {
  /// Drops attributes that can't be represented as JSON, unwrapping any
  /// ``JSON`` values first.
  static func cleanedAttributes(_ attributes: [String: Any]) -> [String: Any] {
    var cleaned: [String: Any] = [:]
    for (key, value) in attributes {
      var value = value
      if let json = value as? JSON {
        value = json.rawValue
      }
      if JSONSerialization.isValidJSONObject([key: value]) {
        cleaned[key] = value
      }
    }
    return cleaned
  }
}
