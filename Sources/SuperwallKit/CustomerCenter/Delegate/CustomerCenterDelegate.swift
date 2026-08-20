//
//  CustomerCenterDelegate.swift
//
//
//  Created by Claude on 20/08/2026.
//

import Foundation

/// Receives Customer Center events. All methods have default implementations.
///
/// The view controller does not retain its delegate. Keep a strong reference to it for the
/// duration of the presentation — or present via `Superwall.shared.presentCustomerCenter(delegate:)`,
/// which retains the delegate while the Customer Center is presented.
@available(iOS 15.0, *)
public protocol CustomerCenterDelegate: AnyObject {
  /// Called before purchases are restored. Call `resume(true)` to continue or `resume(false)` to cancel.
  func customerCenter(shouldRestorePurchases resume: @escaping (Bool) -> Void)
  /// Called whenever the user taps a path, including custom and URL paths, before the action runs.
  func customerCenter(didSelect action: CustomerCenterAction, for purchase: SubscriptionTransaction?)
  /// Called when the user answers a survey attached to a path.
  func customerCenter(didCompleteSurvey surveyId: String, optionId: String, for action: CustomerCenterAction)
  /// Called when a refund request sheet finishes.
  func customerCenter(didCompleteRefundRequestFor productId: String, status: CustomerCenterRefundStatus)
  /// Called when the Customer Center is dismissed.
  func customerCenterDidDismiss()
}

@available(iOS 15.0, *)
public extension CustomerCenterDelegate {
  func customerCenter(shouldRestorePurchases resume: @escaping (Bool) -> Void) { resume(true) }
  func customerCenter(didSelect action: CustomerCenterAction, for purchase: SubscriptionTransaction?) {}
  func customerCenter(didCompleteSurvey surveyId: String, optionId: String, for action: CustomerCenterAction) {}
  func customerCenter(didCompleteRefundRequestFor productId: String, status: CustomerCenterRefundStatus) {}
  func customerCenterDidDismiss() {}
}

/// Objective-C variant of ``CustomerCenterDelegate``.
///
/// The view controller does not retain its delegate. Keep a strong reference to it for the
/// duration of the presentation — or present via `Superwall.shared.presentCustomerCenter(delegate:)`,
/// which retains the delegate while the Customer Center is presented.
@available(iOS 15.0, *)
@objc(SWKCustomerCenterDelegate)
public protocol CustomerCenterDelegateObjc: AnyObject {
  @objc optional func customerCenter(shouldRestorePurchases resume: @escaping (Bool) -> Void)
  @objc optional func customerCenter(didSelect action: CustomerCenterActionObjc, for purchase: SubscriptionTransaction?)
  @objc optional func customerCenter(didCompleteSurvey surveyId: String, optionId: String, for action: CustomerCenterActionObjc)
  @objc optional func customerCenter(didCompleteRefundRequestFor productId: String, status: CustomerCenterRefundStatus)
  @objc optional func customerCenterDidDismiss()
}
