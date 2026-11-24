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
/// is handed over for sending, so an upload that fails isn't sent again until the
/// SDKs change.
struct SDKEnvironmentReporter {
  var scan: () async -> SDKEnvironmentScan
  var savedHash: () -> String?
  var saveHash: (String) -> Void
  /// Tracks the event, and returns whether it was handed over for sending.
  var send: (SDKEnvironmentInfo) async -> Bool

  /// Returns whether it sent the event.
  @discardableResult
  func reportIfChanged() async -> Bool {
    let scan = await scan()
    guard scan.sdkHash != savedHash() else {
      return false
    }
    // Saved only once it's handed over, so a launch with `eventTrackingBehavior`
    // set to `.none` doesn't use up the change.
    guard await send(scan.info()) else {
      return false
    }
    saveHash(scan.sdkHash)
    return true
  }

  static func live(superwall: Superwall) -> SDKEnvironmentReporter {
    let storage: Storage = superwall.dependencyContainer.storage
    return SDKEnvironmentReporter(
      scan: {
        await SDKEnvironmentCollector.shared.scan()
      },
      savedHash: {
        storage.get(SDKEnvironmentHash.self)
      },
      saveHash: { hash in
        storage.save(hash, forType: SDKEnvironmentHash.self)
      },
      send: { info in
        // The queue learns of a tracking-behavior change asynchronously, so check
        // the options too.
        if superwall.dependencyContainer.configManager.options.eventTrackingBehavior == .none {
          return false
        }
        // The event goes up as it's tracked, in a request of its own.
        let result = await superwall.track(PrivateSuperwallEvent.SDKEnvironment(info: info))
        return result.isQueuedForSending
      }
    )
  }
}

/// Runs the report once per process. Configuring and the app becoming active can
/// both start the app launch check at once, and reports that overlapped would each
/// read the old hash and send the same SDKs twice.
actor SDKEnvironmentReportOnce {
  static let shared = SDKEnvironmentReportOnce()
  private var report: Task<Bool, Never>?

  /// Returns whether the report sent the event. Later callers wait for the first
  /// report and get its result.
  @discardableResult
  func run(_ makeReporter: @escaping @Sendable () -> SDKEnvironmentReporter) async -> Bool {
    if let report = report {
      return await report.value
    }
    let report = Task {
      await makeReporter().reportIfChanged()
    }
    self.report = report
    return await report.value
  }
}
