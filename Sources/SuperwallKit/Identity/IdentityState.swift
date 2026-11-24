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
/// One call to `identify(userId:)` that changes the user. Pending work is
/// keyed by it rather than by user id, so that each identify resolves only
/// its own work, even when the same user is identified again before an
/// earlier identify's work has finished.
struct IdentifyOperation: Hashable {
  let userId: String
  let id: UUID

  init(userId: String, id: UUID = UUID()) {
    self.userId = userId
    self.id = id
  }
}

/// What's known about deriving a user's seed from their id.
enum UserIdSeed: Equatable {
  /// User id seeds are on, and this is the user's.
  case derived(Int)
  /// User id seeds are off, so the user keeps the seed they have.
  case off
  /// The config didn't arrive, so it isn't known yet.
  case unknown
}

struct IdentityState {
  /// Work that has to finish before the identity is ready.
  enum Pending: Hashable {
    /// `configure()` is running, possibly waiting for assignments.
    case configuration
    /// The seed for this identify's user is waiting on the config.
    case seed(IdentifyOperation)
    /// Assignments are being restored for this identify's user before the
    /// identity is ready.
    case assignments(IdentifyOperation)
    /// `Superwall.reset()` is cleaning up after the user it replaced.
    case reset(UUID)
  }

  enum Keys {
    static let appUserId = "appUserId"
    static let aliasId = "aliasId"
    static let seed = "seed"
  }

  var appUserId: String?
  var aliasId: String
  var seed: Int
  /// Whether the logged in user's seed is still waiting on the config to say
  /// if it's derived from their id. Saved, so that if the config doesn't
  /// arrive in this launch, the next one asks again.
  var seedAwaitsConfig: Bool
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
    seedAwaitsConfig: Bool = false,
    userAttributes: [String: Any] = [:],
    pending: Set<Pending> = [],
    hasResolved: Bool = false,
    appInstalledAtString: String
  ) {
    self.appUserId = appUserId
    self.aliasId = aliasId
    self.seed = seed
    self.seedAwaitsConfig = seedAwaitsConfig
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
  /// Logs in as the operation's user, keeping the alias. They take `seed`
  /// if the app's options derive seeds from user ids. Without one they keep
  /// the current seed, which is pending until the config says whether to
  /// derive it.
  case identify(IdentifyOperation, seed: Int?)
  /// Resolves the operation's pending seed. Applies what the config said if
  /// the operation's user is still the logged in user, otherwise only
  /// resolves it. A seed that's still unknown keeps waiting on the config.
  case resolveSeed(IdentifyOperation, UserIdSeed)
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
    case let .identify(operation, seed):
      guard operation.userId != state.appUserId else {
        return state
      }
      state.appUserId = operation.userId
      if let seed = seed {
        state.seed = seed
      } else {
        state.pending.insert(.seed(operation))
      }
      state.seedAwaitsConfig = seed == nil
      return state.mergingIds()
    case let .resolveSeed(operation, userIdSeed):
      state.pending.remove(.seed(operation))
      guard operation.userId == state.appUserId else {
        return state
      }
      switch userIdSeed {
      case .derived(let seed):
        state.seedAwaitsConfig = false
        if seed != state.seed {
          state.seed = seed
          return state.mergingIds()
        }
      case .off:
        state.seedAwaitsConfig = false
      case .unknown:
        break
      }
      return state
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
