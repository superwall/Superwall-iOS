//
//  SilentTestModeStatusSink.swift
//  SuperwallKit
//
//  Created by Superwall on 09/11/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Foundation

/// Drops what test mode would send to `Superwall.shared`, so tests that only
/// check test mode's own state can't change the status other tests read.
struct SilentTestModeStatusSink: TestModeStatusSink {
  func send(customerInfo: CustomerInfo, status: SubscriptionStatus) {}
  func sendTestModeEnded() {}
}

extension DependencyContainer {
  /// Replaces the container's test mode manager with one that sends nothing
  /// to `Superwall.shared`, and returns it.
  func silentTestModeManager(defaults: UserDefaults = .standard) -> TestModeManager {
    let manager = TestModeManager(
      identityManager: identityManager,
      deviceHelper: deviceHelper,
      storage: storage,
      defaults: defaults,
      statusSink: SilentTestModeStatusSink()
    )
    testModeManager = manager
    deviceHelper.testModeManager = manager
    return manager
  }
}
