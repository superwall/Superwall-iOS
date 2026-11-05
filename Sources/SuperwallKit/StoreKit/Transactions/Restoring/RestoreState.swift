//
//  RestoreState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

/// Holds ``RestoreState``. Restores have no store actions: they wait on the
/// purchase controller, so they run in the caller's task and change the
/// state only through ``RestoreUpdate`` reducers.
typealias RestoreStore = StateStore<Void, RestoreState>

/// Where restores stand, held by ``RestoreFlow``.
///
/// Restores aren't deduplicated, and one can start another (with a purchase
/// controller, a paywall's restore runs the app's restore), so this counts
/// the ones running.
struct RestoreState {
  /// How many restores are running.
  var running = 0

  var isRestoring: Bool {
    running > 0
  }
}

/// The ways ``RestoreState`` can change.
enum RestoreUpdate: Reducer {
  case begin
  case finish

  func reduce(_ state: RestoreState) -> RestoreState {
    var state = state
    switch self {
    case .begin:
      state.running += 1
    case .finish:
      state.running = max(state.running - 1, 0)
    }
    return state
  }
}
