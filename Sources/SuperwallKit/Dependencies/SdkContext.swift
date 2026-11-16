//
//  SdkContext.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//

import Foundation

/// What one part of the SDK asks of another. A store's context reaches the
/// rest of the SDK through this rather than holding the managers itself, so
/// it doesn't depend on their concrete types and tests can fake them.
protocol SdkContext: AnyObject {
  /// Waits for the config. Returns `nil` if it never arrives.
  func awaitConfig() async -> Config?

  /// Fetches the user's assignments once the config has arrived.
  func fetchAssignments() async
}

/// The real ``SdkContext``, backed by the SDK's managers.
final class AppSdkContext: SdkContext {
  // Weak, so a side effect that outlives the SDK does nothing rather than
  // keeping its managers alive.
  private weak var configManager: ConfigManager?

  init(configManager: ConfigManager) {
    self.configManager = configManager
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
