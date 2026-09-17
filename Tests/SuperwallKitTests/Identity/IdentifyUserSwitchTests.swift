//
//  IdentifyUserSwitchTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-17.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Identifying a different user resets the previous one from inside the
/// identity manager's queue. Anything that reset does must not wait on that
/// queue, or every later identity call hangs for the rest of the process.
///
/// The identify-triggered reset is wired to the shared instance, so this runs
/// against it. The only assertion is that its queue still answers, which no
/// other suite's use of the instance can make false.
@Suite(.serialized)
struct IdentifyUserSwitchTests {
  @Test("Switching user with cached MMP attribution doesn't hang the identity queue")
  func switchingUserWithCachedAcquisitionAttributesKeepsTheQueueAlive() {
    let superwall = Superwall.shared
    let storage: Storage = superwall.dependencyContainer.storage
    let identityManager: IdentityManager = superwall.dependencyContainer.identityManager

    // An install match that resolved on an earlier launch. It's install-scoped,
    // so the reset re-applies it to the new user.
    storage.save(["acquisition_source": JSON("test_network")], forType: MMPAcquisitionDataStorage.self)
    defer {
      storage.delete(MMPAcquisitionDataStorage.self)
    }

    superwall.identify(userId: "switch-user-a")
    superwall.identify(userId: "switch-user-b")

    // A read on the identity queue only returns if the reset above finished.
    let queueAnswered = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
      _ = identityManager.userAttributes
      queueAnswered.signal()
    }
    guard queueAnswered.wait(timeout: .now() + 3) == .success else {
      // Anything else that touches the queue would hang too, so stop here.
      Issue.record("the identity queue is hung")
      return
    }
    superwall.reset()
  }
}
