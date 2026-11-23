//
//  SDKEnvironmentReportState.swift
//  SuperwallKit
//
//  Created by Superwall on 23/11/2026.
//

import Foundation

typealias SDKEnvironmentReportStore = StateStore<
  SDKEnvironmentReportContext,
  SDKEnvironmentReportState
>

/// Whether this app open's report of the app's SDKs has run, and how it ended.
/// Changed only by ``SDKEnvironmentReportUpdate`` reducers, which
/// ``SDKEnvironmentReportAction``s apply.
struct SDKEnvironmentReportState: Equatable {
  /// How a report ended.
  enum Outcome: Equatable {
    /// The SDKs are the ones last sent, so nothing was sent.
    case unchanged
    /// The event wasn't queued for sending, as when `eventTrackingBehavior` is
    /// `.none`. The hash isn't saved, so the next app open tries again.
    case notQueued
    /// The event was queued for sending and the hash of its SDKs saved.
    case sent
  }

  enum Phase: Equatable {
    /// No report has finished since the app opened.
    case pending
    case finished(Outcome)
  }

  private(set) var phase: Phase = .pending

  /// Whether the report sent the event.
  var didSend: Bool {
    return phase == .finished(.sent)
  }
}

/// The ways ``SDKEnvironmentReportState`` can change.
enum SDKEnvironmentReportUpdate: Reducer {
  /// The SDKs turned out to be the ones last sent.
  case foundUnchanged
  /// The event was turned away instead of being queued for sending.
  case eventNotQueued
  /// The event was queued for sending.
  case eventQueued

  func reduce(_ state: SDKEnvironmentReportState) -> SDKEnvironmentReportState {
    state.applying(self)
  }
}

extension SDKEnvironmentReportState {
  /// The state after `update`. The only place the fields change.
  ///
  /// There's one report per app open, so a report that has finished keeps its
  /// outcome.
  func applying(_ update: SDKEnvironmentReportUpdate) -> SDKEnvironmentReportState {
    if phase != .pending {
      return self
    }
    var state = self
    switch update {
    case .foundUnchanged:
      state.phase = .finished(.unchanged)
    case .eventNotQueued:
      state.phase = .finished(.notQueued)
    case .eventQueued:
      state.phase = .finished(.sent)
    }
    return state
  }
}

/// Everything a report needs. ``LiveSDKEnvironmentReportContext`` provides it in
/// the SDK, and tests provide a fake.
protocol SDKEnvironmentReportContext: AnyObject, Sendable {
  var store: SDKEnvironmentReportStore { get }

  /// The SDKs the app includes. Reads the app's bundles from disk and hashes its
  /// class names, so it can take a while.
  func collectEnvironment() async -> SDKEnvironmentInfo

  /// The hash of the SDKs last sent, if any have been.
  func savedHash() -> String?

  /// Saves the hash of the SDKs just sent. Called with the store unlocked.
  func saveHash(_ hash: String)

  /// Tracks the event, and returns whether it was queued for sending.
  func send(_ info: SDKEnvironmentInfo) async -> Bool
}

/// Every way a report ends. Each runs with the store locked, and returns
/// whether this app open's report sent the event.
enum SDKEnvironmentReportAction: StoreAction {
  /// The SDKs are the ones last sent.
  case finishUnchanged
  /// The event wasn't queued for sending.
  case finishNotQueued
  /// The event for the SDKs with this hash was queued. Saves the hash, so they
  /// aren't sent again until they change.
  case finishSent(sdkHash: String)

  func execute(in context: SDKEnvironmentReportContext) -> Bool {
    let store = context.store
    let before = store.state
    if before.phase != .pending {
      return before.didSend
    }
    switch self {
    case .finishUnchanged:
      store.update(SDKEnvironmentReportUpdate.foundUnchanged)
    case .finishNotQueued:
      store.update(SDKEnvironmentReportUpdate.eventNotQueued)
    case .finishSent(let sdkHash):
      store.update(SDKEnvironmentReportUpdate.eventQueued)
      store.deferUntilUnlocked {
        context.saveHash(sdkHash)
      }
    }
    return store.state.didSend
  }
}
