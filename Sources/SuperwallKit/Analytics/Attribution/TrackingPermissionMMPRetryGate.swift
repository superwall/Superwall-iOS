//
//  TrackingPermissionMMPRetryGate.swift
//  SuperwallKit
//

import Foundation

/// Serialises the post-ATT MMP install-attribution retry so only one runs at a
/// time, and coordinates it with the fire-and-forget initial match started
/// during configure.
actor TrackingPermissionMMPRetryGate {
  private enum State {
    case idle
    case inFlight
    case completed
  }

  private var state: State = .idle

  /// The fire-and-forget initial install-match task started during configure,
  /// if any. The post-ATT retry awaits this before sending its upgraded
  /// request so the slower pre-ATT response can't finish last and overwrite
  /// the deterministic post-ATT `acquisition_*` attributes.
  private var initialMatchTask: Task<Void, Never>?

  func setInitialMatchTask(_ task: Task<Void, Never>) {
    initialMatchTask = task
  }

  /// Waits for the in-flight initial match (if one was started) to finish.
  func awaitInitialMatch() async {
    await initialMatchTask?.value
  }

  func tryBegin() -> Bool {
    guard case .idle = state else {
      return false
    }

    state = .inFlight
    return true
  }

  func finish(didComplete: Bool) {
    state = didComplete ? .completed : .idle
  }
}
