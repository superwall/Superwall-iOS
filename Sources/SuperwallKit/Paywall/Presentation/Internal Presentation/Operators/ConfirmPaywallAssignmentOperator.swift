//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == PresentablePipelineOutput, Failure == Error {
  /// Confirms the paywall assignment, if it exists.
  ///
  /// This is split from the holdout assignment because overrides can make the
  /// paywall present even if the user is subscribed. We only know the overrides
  /// at this point.
  func confirmPaywallAssignment() -> AnyPublisher<PresentablePipelineOutput, Failure> {
    map { input in
      // Debuggers shouldn't confirm assignments.
      if input.request.flags.isDebuggerLaunched {
        return input
      }

      if let confirmableAssignment = input.confirmableAssignment {
        input.request.dependencyContainer.configManager.confirmAssignment(confirmableAssignment)
      }
      return input
    }
    .eraseToAnyPublisher()
  }
}
