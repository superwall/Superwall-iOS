//
//  SDKEnvironmentReporter.swift
//  SuperwallKit
//
//  Created by Jake Mor on 23/10/2026.
//

import Foundation

/// Sends the SDK list on app open, only when it differs from the last one sent.
///
/// It goes up once per change, with no retry: the hash is saved as soon as the event
/// is queued, so an upload that fails isn't sent again until the SDKs change.
///
/// One report runs per app open. Configuring and the app becoming active can both
/// start the app launch check at once, and reports that overlapped would each read
/// the old hash and send the same SDKs twice. So they run one at a time on a
/// ``SerialTaskCoordinator``, and all but the first find the report already done.
/// Everything a report causes goes through its ``SDKEnvironmentReportContext``.
final class SDKEnvironmentReporter: Sendable {
  static let shared = SDKEnvironmentReporter(context: LiveSDKEnvironmentReportContext())

  private let context: SDKEnvironmentReportContext
  private let queue = SerialTaskCoordinator()

  init(context: SDKEnvironmentReportContext) {
    self.context = context
  }

  /// Returns whether this app open's report sent the event. Later callers wait for
  /// the first report and get its result.
  @discardableResult
  func reportIfChanged() async -> Bool {
    return await withCheckedContinuation { continuation in
      queue.enqueue { [context] in
        let didSend = await Self.report(in: context)
        continuation.resume(returning: didSend)
      }
    }
  }

  private static func report(in context: SDKEnvironmentReportContext) async -> Bool {
    let store = context.store
    if case .finished(let outcome) = store.read({ $0.phase }) {
      return outcome == .sent
    }
    let info = await context.collectEnvironment()
    if info.sdkHash == context.savedHash() {
      return store.dispatch(SDKEnvironmentReportAction.finishUnchanged, in: context)
    }
    // Saved only once it's queued, so a launch with `eventTrackingBehavior` set to
    // `.none` doesn't use up the change.
    if await context.send(info) {
      return store.dispatch(
        SDKEnvironmentReportAction.finishSent(sdkHash: info.sdkHash),
        in: context
      )
    }
    return store.dispatch(SDKEnvironmentReportAction.finishNotQueued, in: context)
  }
}

/// Reports on the running app through the shared ``Superwall`` instance.
final class LiveSDKEnvironmentReportContext: SDKEnvironmentReportContext {
  let store = SDKEnvironmentReportStore(initial: SDKEnvironmentReportState())

  func collectEnvironment() async -> SDKEnvironmentInfo {
    // Reading the bundles touches the disk and hashing the class names takes a
    // few milliseconds, so keep it off the main thread.
    return await Task.detached(priority: .utility) {
      SDKEnvironmentLogic.collect(from: .live)
    }
    .value
  }

  func savedHash() -> String? {
    return Superwall.shared.dependencyContainer.storage.get(SDKEnvironmentHash.self)
  }

  func saveHash(_ hash: String) {
    Superwall.shared.dependencyContainer.storage.save(hash, forType: SDKEnvironmentHash.self)
  }

  func send(_ info: SDKEnvironmentInfo) async -> Bool {
    let superwall = Superwall.shared
    let result = await superwall.track(PrivateSuperwallEvent.SDKEnvironment(info: info))
    if !result.isQueuedForSending {
      return false
    }
    // The queue lives in memory and flushes every 20 seconds. Send now, since
    // the hash is about to be saved and stopping the app first, as rerunning
    // it from Xcode does, would lose the change.
    await superwall.dependencyContainer.placementsQueue.flushInternal()
    return true
  }
}
