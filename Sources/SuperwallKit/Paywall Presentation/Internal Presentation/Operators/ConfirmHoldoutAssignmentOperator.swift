//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/12/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == AssignmentPipelineOutput, Failure == Error {
  /// Confirms the assignment for a holdout, if it exists.
  ///
  /// We can't confirm a paywall assignment here because there may be factors that prevent
  /// it from showing later on.
  func confirmHoldoutAssignment() -> AnyPublisher<AssignmentPipelineOutput, Failure> {
    map { input in
      switch input.triggerResult {
      case .holdout:
        if let confirmableAssignment = input.confirmableAssignment {
          input.request.injections.configManager.confirmAssignment(confirmableAssignment)
        }
      default:
        break
      }
      return input
    }
    .eraseToAnyPublisher()
  }
}
