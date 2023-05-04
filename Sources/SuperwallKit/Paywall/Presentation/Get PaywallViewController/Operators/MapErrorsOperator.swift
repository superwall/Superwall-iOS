//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/05/2023.
//

import Foundation
import Combine

extension AnyPublisher where Output == PaywallViewController, Failure == Error {
  func mapErrors(isObjc: Bool) -> AnyPublisher<PaywallViewController, Error> {
    mapError { error -> Error in
      if let error = error as? PresentationPipelineError {
        switch error {
        case .holdout(let experiment):
          if isObjc {
            return PaywallSkippedReasonObjc.holdout
          } else {
            return PaywallSkippedReason.holdout(experiment)
          }
        case .noRuleMatch:
          if isObjc {
            return PaywallSkippedReasonObjc.noRuleMatch
          } else {
            return PaywallSkippedReason.noRuleMatch
          }
        case .eventNotFound:
          if isObjc {
            return PaywallSkippedReasonObjc.eventNotFound
          } else {
            return PaywallSkippedReason.eventNotFound
          }
        case .userIsSubscribed:
          if isObjc {
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
    .eraseToAnyPublisher()
  }
}
