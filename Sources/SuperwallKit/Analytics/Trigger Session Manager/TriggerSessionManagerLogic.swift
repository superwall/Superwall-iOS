//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//

import UIKit
import StoreKit

enum TriggerSessionManagerLogic {
  static func outcome(
    presentationInfo: PresentationInfo,
    triggerResult: TriggerResult?
  ) -> TriggerSession.PresentationOutcome? {
    switch presentationInfo {
    case .implicitTrigger,
      .explicitTrigger:
      guard let triggerResult = triggerResult else {
        return nil
      }
      switch triggerResult {
      case .error,
        .eventNotFound:
        // Error
        return nil
      case .holdout:
        return .holdout
      case .noRuleMatch:
        return .noRuleMatch
      case .paywall:
        return .paywall
      }
    case .fromIdentifier:
      return .paywall
    }
  }
}
