//
//  CustomerCenterDelegate.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

/// Receives Customer Center events. All methods have default implementations, and all are called
/// on the main actor.
///
/// The view controller does not retain its delegate. Keep a strong reference to it for the
/// duration of the presentation — or present via `Superwall.shared.presentCustomerCenter(delegate:)`,
/// which retains the delegate while the Customer Center is presented.
@available(iOS 15.0, *)
@MainActor
public protocol CustomerCenterDelegate: AnyObject {
  /// Called before purchases are restored. Return `false` to cancel, for example after the user
  /// declines to sign in.
  func customerCenterShouldRestorePurchases() async -> Bool
  /// Called whenever the user taps a path, including custom and URL paths, before the action runs.
  /// `pathId` is the tapped path's ``CustomerCenterConfiguration/Path/id``, and `purchase` the
  /// purchase it applies to, or `nil` for a screen-level action such as restore.
  func customerCenterDidSelectAction(_ action: CustomerCenterAction, pathId: String, purchase: CustomerCenterPurchase?)
  /// Called when the user answers a survey attached to a path.
  func customerCenterDidCompleteSurvey(surveyId: String, optionId: String, action: CustomerCenterAction, pathId: String)
  /// Called when a refund request sheet finishes.
  func customerCenterDidCompleteRefundRequest(productId: String, status: CustomerCenterRefundStatus)
  /// Called when the Customer Center is dismissed.
  func customerCenterDidDismiss()
}

@available(iOS 15.0, *)
public extension CustomerCenterDelegate {
  func customerCenterShouldRestorePurchases() async -> Bool { true }
  func customerCenterDidSelectAction(_ action: CustomerCenterAction, pathId: String, purchase: CustomerCenterPurchase?) {}
  func customerCenterDidCompleteSurvey(surveyId: String, optionId: String, action: CustomerCenterAction, pathId: String) {}
  func customerCenterDidCompleteRefundRequest(productId: String, status: CustomerCenterRefundStatus) {}
  func customerCenterDidDismiss() {}
}

/// Objective-C variant of ``CustomerCenterDelegate``.
///
/// The view controller does not retain its delegate. Keep a strong reference to it for the
/// duration of the presentation — or present via `Superwall.shared.presentCustomerCenter(delegate:)`,
/// which retains the delegate while the Customer Center is presented.
@available(iOS 15.0, *)
@objc(SWKCustomerCenterDelegate)
@MainActor
public protocol CustomerCenterDelegateObjc: AnyObject {
  /// Called before purchases are restored. Call `completion(true)` to continue or
  /// `completion(false)` to cancel. Call it exactly once: the restore waits until you do, and any
  /// call after the first is ignored.
  @objc optional func customerCenterShouldRestorePurchases(completion: @escaping (Bool) -> Void)
  @objc optional func customerCenterDidSelectAction(
    _ action: CustomerCenterActionObjc,
    pathId: String,
    purchase: CustomerCenterPurchase?
  )
  @objc optional func customerCenterDidCompleteSurvey(
    surveyId: String,
    optionId: String,
    action: CustomerCenterActionObjc,
    pathId: String
  )
  @objc optional func customerCenterDidCompleteRefundRequest(productId: String, status: CustomerCenterRefundStatus)
  @objc optional func customerCenterDidDismiss()
}
