//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/11/2022.
//

import Foundation
import Combine

struct TriggerResultPipelineOutput {
  let request: PresentationRequest
  let triggerResult: TriggerResult
  let debugInfo: DebugInfo
}

extension AnyPublisher where Output == AssignmentPipelineOutput, Failure == Error {
  /// Checks whether the trigger result indicates that a paywall should show.
  func checkForPaywallResult() -> AnyPublisher<TriggerResultResponsePipelineOutput, Error> {
    tryMap { input in
      switch input.triggerResult {
      case .paywall(let experiment):
        return TriggerResultResponsePipelineOutput(
          request: input.request,
          triggerResult: input.triggerResult,
          debugInfo: input.debugInfo,
          confirmableAssignment: nil,
          experiment: experiment
        )
      default:
        throw GetPresentationResultError.willNotPresent(input.triggerResult)
      }
    }
    .eraseToAnyPublisher()
  }
}
