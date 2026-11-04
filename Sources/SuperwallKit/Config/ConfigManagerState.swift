//
//  ConfigManagerState.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

typealias ConfigStore = SequentialStore<ConfigManager, ConfigManagerState>

/// What ``ConfigManager`` knows about the config. Changed only by
/// ``ConfigUpdate`` reducers on its store.
///
/// What's published lives in ``configState``, an enum whose cases carry their
/// own data. The other fields don't depend on its case:
/// - The triggers are those of the config being applied. They take effect as
///   soon as a config arrives, before it's published, so that events tracked
///   while purchases load can still trigger paywalls. During a refresh they're
///   the new config's while the old one is still published.
/// - The retry count and the initial purchases load belong to the requests
///   and loads, whatever the published state is.
struct ConfigManagerState {
  var configState: ConfigState = .retrieving
  var triggersByPlacementName: [String: Trigger] = [:]
  /// How many times the last config request was retried.
  var retryCount = 0
  /// The purchases load that config was published ahead of, when the saved
  /// customer info proved the user was still entitled.
  var initialPurchasesLoad: Task<Void, Never>?

  var config: Config? {
    configState.getConfig()
  }
}

/// The ways ``ConfigManagerState`` can change.
enum ConfigUpdate: Reducer {
  /// The config request is being retried.
  case retrying(attempt: Int)
  /// Records a retry of a request that doesn't change the config state, such
  /// as a refresh.
  case retryCount(Int)
  case triggers([String: Trigger])
  case initialPurchasesLoad(Task<Void, Never>)
  case retrieved(Config)
  case failed(Error)
  /// Sets the config state directly.
  case set(ConfigState)

  func reduce(_ state: ConfigManagerState) -> ConfigManagerState {
    var state = state
    switch self {
    case .retrying(let attempt):
      state.retryCount = attempt
      state.configState = .retrying
    case .retryCount(let attempt):
      state.retryCount = attempt
    case .triggers(let triggers):
      state.triggersByPlacementName = triggers
    case .initialPurchasesLoad(let task):
      state.initialPurchasesLoad = task
    case .retrieved(let config):
      state.configState = .retrieved(config)
    case .failed(let error):
      state.configState = .failed(error)
    case .set(let configState):
      state.configState = configState
    }
    return state
  }

  /// What `ConfigManager.configState` should publish after this update, if
  /// anything.
  var publication: ConfigPublication? {
    switch self {
    case .retrying:
      return .value(.retrying)
    case .retrieved(let config):
      return .value(.retrieved(config))
    case .set(.failed(let error)):
      return .failure(error)
    case .set(let configState):
      return .value(configState)
    case .failed(let error):
      return .failure(error)
    case .retryCount,
      .triggers,
      .initialPurchasesLoad:
      return nil
    }
  }
}

enum ConfigPublication {
  case value(ConfigState)
  case failure(Error)
}

/// The config work that mustn't overlap. Fetching and refreshing both apply
/// a new config, so they run one at a time, in the order they were called.
enum ConfigAction: StoreAction {
  case fetch
  case refresh(oldConfig: Config?, isUserInitiated: Bool)

  func execute(in context: ConfigManager) async {
    switch self {
    case .fetch:
      await context.performFetchConfiguration()
    case let .refresh(oldConfig, isUserInitiated):
      await context.performRefreshConfiguration(
        oldConfig: oldConfig,
        isUserInitiated: isUserInitiated
      )
    }
  }
}

extension ConfigAction: CustomStringConvertible {
  var description: String {
    switch self {
    case .fetch:
      return "fetch"
    case let .refresh(oldConfig, isUserInitiated):
      return "refresh(oldConfig: \(oldConfig?.buildId ?? "nil"), isUserInitiated: \(isUserInitiated))"
    }
  }
}
