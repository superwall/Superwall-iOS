//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

struct TriggerResultPipelineOutput {
  let request: PresentationRequest
  let triggerResult: TriggerResult
  let debugInfo: DebugInfo
}

extension AnyPublisher where Output == AssignmentPipelineOutput, Failure == Error {
  /// Confirms the paywall assignment, if it exists.
  func confirmAssignment(configManager: ConfigManager = .shared) -> AnyPublisher<TriggerResultPipelineOutput, Failure> {
    map { input in
      if let confirmableAssignment = input.confirmableAssignment {
        configManager.confirmAssignment(confirmableAssignment)
      }

      return TriggerResultPipelineOutput(
        request: input.request,
        triggerResult: input.triggerResult,
        debugInfo: input.debugInfo
      )
    }
    .eraseToAnyPublisher()
  }
}
