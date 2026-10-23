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
struct SDKEnvironmentReporter {
  var environment: () async -> SDKEnvironmentInfo
  var savedHash: () -> String?
  var saveHash: (String) -> Void
  /// Tracks the event, and returns whether it was queued for sending.
  var send: (SDKEnvironmentInfo) async -> Bool

  /// Returns whether it sent the event.
  @discardableResult
  func reportIfChanged() async -> Bool {
    let info = await environment()
    guard info.sdkHash != savedHash() else {
      return false
    }
    // Saved only once it's queued, so a launch with `eventTrackingBehavior` set to
    // `.none` doesn't use up the change.
    guard await send(info) else {
      return false
    }
    saveHash(info.sdkHash)
    return true
  }

  static func live(storage: Storage) -> SDKEnvironmentReporter {
    return SDKEnvironmentReporter(
      environment: {
        await SDKEnvironmentCollector.shared.environment()
      },
      savedHash: {
        storage.get(SDKEnvironmentHash.self)
      },
      saveHash: { hash in
        storage.save(hash, forType: SDKEnvironmentHash.self)
      },
      send: { info in
        let superwall = Superwall.shared
        let result = await superwall.track(PrivateSuperwallEvent.SDKEnvironment(info: info))
        guard result.isQueuedForSending else {
          return false
        }
        // The queue lives in memory and flushes every 20 seconds. Send now, since
        // the hash is about to be saved and stopping the app first, as rerunning
        // it from Xcode does, would lose the change.
        await superwall.dependencyContainer.placementsQueue.flushInternal()
        return true
      }
    )
  }
}
