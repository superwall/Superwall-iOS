//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation

extension Superwall {
  /// Confirms the paywall assignment, if it exists.
  ///
  /// This is split from the holdout assignment because overrides can make the
  /// paywall present even if the user is subscribed. We only know the overrides
  /// at this point.
  ///
  /// - Parameters:
  ///   - confirmableAssignment: The assignment to confirm.
  ///   - isDebuggerLaunched: A boolean that indicates whether the debugger is launched.
  ///   - dependendencyContainer: Used for tests only.
  func confirmPaywallAssignment(
    _ confirmableAssignment: ConfirmableAssignment?,
    isDebuggerLaunched: Bool,
    dependencyContainer: DependencyContainer? = nil
  ) {
    let dependencyContainer = dependencyContainer ?? self.dependencyContainer
    // Debuggers shouldn't confirm assignments.
    if isDebuggerLaunched {
      return
    }

    if let confirmableAssignment = confirmableAssignment {
      dependencyContainer.configManager.confirmAssignment(confirmableAssignment)
    }
  }
}
