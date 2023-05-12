//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/05/2023.
//

import Foundation

extension Superwall {
  func mapError(_ error: Error, toObjc: Bool) -> Error {
    if let error = error as? PresentationPipelineError {
      switch error {
      case .holdout(let experiment):
        if toObjc {
          return PaywallSkippedReasonObjc.holdout
        } else {
          return PaywallSkippedReason.holdout(experiment)
        }
      case .noRuleMatch:
        if toObjc {
          return PaywallSkippedReasonObjc.noRuleMatch
        } else {
          return PaywallSkippedReason.noRuleMatch
        }
      case .eventNotFound:
        if toObjc {
          return PaywallSkippedReasonObjc.eventNotFound
        } else {
          return PaywallSkippedReason.eventNotFound
        }
      case .userIsSubscribed:
        if toObjc {
          return PaywallSkippedReasonObjc.userIsSubscribed
        } else {
          return PaywallSkippedReason.userIsSubscribed
        }
      default:
        return error
      }
    }
    return error
  }
}
