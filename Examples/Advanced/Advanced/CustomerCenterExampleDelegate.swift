//
//  CustomerCenterExampleDelegate.swift
//  Advanced
//
//  Created by Claude on 20/08/2026.
//

import Foundation
import SuperwallKit

/// An example `CustomerCenterDelegate` that prints each callback it receives.
///
/// `Superwall.shared.presentCustomerCenter(delegate:)` retains this for the duration of the
/// presentation, so it's safe to create a fresh instance each time you present.
final class CustomerCenterExampleDelegate: CustomerCenterDelegate {
  func customerCenter(shouldRestorePurchases resume: @escaping (Bool) -> Void) {
    print("[Customer Center] shouldRestorePurchases")
    resume(true)
  }

  func customerCenter(didSelect action: CustomerCenterAction, for purchase: SubscriptionTransaction?) {
    print("[Customer Center] didSelect action: \(action), purchase: \(String(describing: purchase))")
  }

  func customerCenter(didCompleteSurvey surveyId: String, optionId: String, for action: CustomerCenterAction) {
    print("[Customer Center] didCompleteSurvey: \(surveyId), optionId: \(optionId), action: \(action)")
  }

  func customerCenter(didCompleteRefundRequestFor productId: String, status: CustomerCenterRefundStatus) {
    print("[Customer Center] didCompleteRefundRequestFor: \(productId), status: \(status)")
  }

  func customerCenterDidDismiss() {
    print("[Customer Center] didDismiss")
  }
}
