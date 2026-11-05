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
/// the ones running and keeps where the latest was started from.
struct RestoreState {
  /// How many restores are running.
  var running = 0
  /// Where the latest running restore was started from.
  var source: RestoreSource?

  var isRestoring: Bool {
    running > 0
  }
}

/// The ways ``RestoreState`` can change.
enum RestoreUpdate: Reducer {
  case begin(RestoreSource)
  case finish

  func reduce(_ state: RestoreState) -> RestoreState {
    var state = state
    switch self {
    case .begin(let source):
      state.running += 1
      state.source = source
    case .finish:
      state.running = max(state.running - 1, 0)
      if state.running == 0 {
        state.source = nil
      }
    }
    return state
  }
}
