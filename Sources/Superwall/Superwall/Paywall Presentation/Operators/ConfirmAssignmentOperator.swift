//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

struct TriggerOutcomePipelineOutput {
  let request: PaywallPresentationRequest
  let triggerOutcome: TriggerResultOutcome
  let debugInfo: DebugInfo
}

extension AnyPublisher where Output == AssignmentPipelineOutput, Failure == Error {
  func confirmAssignment(configManager: ConfigManager = .shared) -> AnyPublisher<TriggerOutcomePipelineOutput, Failure> {
    map { input in
      if let confirmableAssignment = input.confirmableAssignment {
        configManager.confirmAssignment(confirmableAssignment)
      }

      return TriggerOutcomePipelineOutput(
        request: input.request,
        triggerOutcome: input.triggerOutcome,
        debugInfo: input.debugInfo
      )
    }
    .eraseToAnyPublisher()
  }
}
