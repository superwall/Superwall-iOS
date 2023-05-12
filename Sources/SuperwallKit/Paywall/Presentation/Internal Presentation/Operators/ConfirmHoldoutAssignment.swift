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
  func confirmHoldoutAssignment(input: AssignmentPipelineOutput) {
    guard case .holdout = input.triggerResult else {
      return
    }
    if let confirmableAssignment = input.confirmableAssignment {
      dependencyContainer.configManager.confirmAssignment(confirmableAssignment)
    }
  }
}
