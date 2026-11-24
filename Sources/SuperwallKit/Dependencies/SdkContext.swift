//
//  SdkContext.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//

import Foundation

/// What one part of the SDK asks of another. An owner that is its own store
/// context, as `IdentityManager` is, reaches the rest of the SDK through this
/// rather than holding the managers itself, so it doesn't depend on their
/// concrete types and tests can fake them. A flow with a separate real
/// context, such as `AppTransactionContext`, keeps its managers there instead.
///
/// Whoever uses this holds it strongly, and side effects can outlive the SDK,
/// so an implementation holds its managers weakly and does nothing once
/// they're gone.
protocol SdkContext: AnyObject {
  /// Whether the app's options turn user ID seeds on. Doesn't wait.
  var isUserIdSeedEnabledInOptions: Bool { get }

  /// Waits for the config. Returns `nil` if it never arrives.
  func awaitConfig() async -> Config?

  /// Fetches the user's assignments once the config has arrived.
  func fetchAssignments() async
}

/// The real ``SdkContext``, backed by the SDK's managers.
final class AppSdkContext: SdkContext {
  private weak var configManager: ConfigManager?

  init(configManager: ConfigManager) {
    self.configManager = configManager
  }

  var isUserIdSeedEnabledInOptions: Bool {
    return configManager?.options.enableUserIdSeed == true
  }

  func awaitConfig() async -> Config? {
    guard let configManager = configManager else {
      return nil
    }
    return try? await configManager.configState
      .compactMap { $0.getConfig() }
      .throwableAsync()
  }

  func fetchAssignments() async {
    try? await configManager?.getAssignments()
  }
}
