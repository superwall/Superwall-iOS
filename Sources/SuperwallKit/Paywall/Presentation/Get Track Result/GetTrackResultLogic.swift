//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/03/2023.
//

import Foundation

enum GetTrackResultLogic {
  static func convertTriggerResult(_ triggerResult: TriggerResult) -> PresentationResult {
    switch triggerResult {
    case .eventNotFound:
      return .eventNotFound
    case .holdout(let experiment):
      return .holdout(experiment)
    case .error:
      return .paywallNotAvailable
    case .noRuleMatch:
      return .noRuleMatch
    case .paywall(let paywall):
      return .paywall(paywall)
    }
  }
}
