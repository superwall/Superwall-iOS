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
/// identity manager's identify action. Anything that reset does must not wait
/// for identity changes to finish, or every later identity change hangs for
/// the rest of the process.
///
/// The identify-triggered reset is wired to the shared instance, so this runs
/// against it.
@Suite(.serialized)
struct IdentifyUserSwitchTests {
  @Test("Switching user with cached MMP attribution doesn't hang identity changes")
  func switchingUserWithCachedAcquisitionAttributesKeepsTheQueueAlive() async {
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

    // The reset re-applies the cached attribution to the new user. Its merge
    // is queued behind the identify, so this only holds once both have run.
    let reapplied = await eventually {
      identityManager.appUserId == "switch-user-b"
        && identityManager.userAttributes["acquisition_source"] as? String == "test_network"
    }
    #expect(reapplied, "identity changes stopped running after the user switch")
    superwall.reset()
  }

  @Test("Switching user starts the new user on a fresh alias without the old user's attributes")
  func switchingUserStartsAFreshIdentity() async {
    let superwall = Superwall.shared
    let identityManager: IdentityManager = superwall.dependencyContainer.identityManager

    superwall.identify(userId: "switch-fresh-a")
    identityManager.mergeUserAttributes(["only_for_a": true])
    let identifiedA = await eventually {
      identityManager.appUserId == "switch-fresh-a"
        && identityManager.userAttributes["only_for_a"] as? Bool == true
    }
    #expect(identifiedA)
    let aliasA = identityManager.aliasId

    superwall.identify(userId: "switch-fresh-b")
    let identifiedB = await eventually { identityManager.appUserId == "switch-fresh-b" }
    #expect(identifiedB)

    #expect(identityManager.aliasId != aliasA)
    #expect(identityManager.userAttributes["only_for_a"] == nil)
    #expect(identityManager.userAttributes["appUserId"] as? String == "switch-fresh-b")
    superwall.reset()
  }

  private func eventually(
    timeout: TimeInterval = 3,
    _ condition: () -> Bool
  ) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() {
        return true
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
  }
}
