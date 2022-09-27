//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation

import Foundation
import Combine

typealias TriggerOutcomePipelineData = (
  request: PaywallPresentationRequest,
  triggerOutcome: TriggerResultOutcome,
  debugInfo: DebugInfo
)

extension AnyPublisher where Output == AssignmentPipelineData, Failure == Error {
  func confirmAssignment(configManager: ConfigManager = .shared) -> AnyPublisher<TriggerOutcomePipelineData, Failure> {
    self
      .map { request, triggerOutcome, confirmableAssignment, debugInfo in
        if let confirmableAssignment = confirmableAssignment {
          configManager.confirmAssignments(confirmableAssignment)
        }
        return (request, triggerOutcome, debugInfo)
       }
      .eraseToAnyPublisher()
  }
}



