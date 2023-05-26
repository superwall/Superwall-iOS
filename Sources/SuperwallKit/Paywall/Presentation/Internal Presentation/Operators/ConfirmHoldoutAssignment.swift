//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation

extension Superwall {
  /// Confirms the assignment for a holdout, if it exists.
  ///
  /// We can't confirm a paywall assignment here because there may be factors that prevent
  /// it from showing later on.
  ///
  /// - Parameters:
  ///   - rulesOutput: The output from evaluating rules.
  ///   - dependencyContainer: Used for testing only.
  func confirmHoldoutAssignment(
    rulesOutput: EvaluateRulesOutput,
    dependencyContainer: DependencyContainer? = nil
  ) {
    let dependencyContainer = dependencyContainer ?? self.dependencyContainer
    guard case .holdout = rulesOutput.triggerResult else {
      return
    }
    if let confirmableAssignment = rulesOutput.confirmableAssignment {
      dependencyContainer.configManager.confirmAssignment(confirmableAssignment)
    }
  }
}
