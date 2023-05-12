//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/05/2023.
//

import Foundation

struct TriggerResultPipelineOutput {
  let request: PresentationRequest
  let triggerResult: TriggerResult
  let debugInfo: [String: Any]
}

extension Superwall {
  func checkForPaywallResult(
    triggerResult: TriggerResult,
    debugInfo: [String: Any]
  ) throws -> TriggerResultResponsePipelineOutput {
    switch triggerResult {
    case .paywall(let experiment):
      return TriggerResultResponsePipelineOutput(
        triggerResult: triggerResult,
        debugInfo: debugInfo,
        confirmableAssignment: nil,
        experiment: experiment
      )
    case .error:
      throw PresentationPipelineError.noPaywallViewController
    case .eventNotFound:
      throw PresentationPipelineError.eventNotFound
    case .holdout(let experiment):
      throw PresentationPipelineError.holdout(experiment)
    case .noRuleMatch:
      throw PresentationPipelineError.noRuleMatch
    }
  }
}
