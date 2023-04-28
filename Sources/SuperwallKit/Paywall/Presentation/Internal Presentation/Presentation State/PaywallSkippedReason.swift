//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/09/2022.
//

import Foundation

/// The reason the paywall presentation was skipped.
public enum PaywallSkippedReason: Sendable, Equatable {
  /// The user was assigned to a holdout.
  ///
  /// A holdout is a control group which you can analyse against
  /// who don't receive any paywall when they match a rule.
  ///
  /// It's useful for testing a paywall's inclusing vs its exclusion.
  case holdout(Experiment)

  /// No rule was matched for this event.
  case noRuleMatch

  /// This event was not found on the dashboard.
  ///
  /// Please make sure you have added the event to a campaign on the dashboard and
  /// double check its spelling.
  case eventNotFound

  /// The user is subscribed.
  ///
  /// This means ``Superwall/subscriptionStatus`` is set to `.active`. If you're
  /// letting Superwall handle subscription-related logic, it will be based on the on-device
  /// receipts. Otherwise it'll be based on the value you've set.
  ///
  /// By default, paywalls do not show to users who are already subscribed. You can override this
  /// behavior in the paywall editor.
  case userIsSubscribed

  /// An error occurred.
  case error(Error)

  public static func == (lhs: PaywallSkippedReason, rhs: PaywallSkippedReason) -> Bool {
    switch (lhs, rhs) {
    case (.noRuleMatch, .noRuleMatch),
      (.eventNotFound, .eventNotFound),
      (.userIsSubscribed, .userIsSubscribed):
      return true
    case let (.holdout(experiment1), .holdout(experiment2)):
      return experiment1 == experiment2
    case let (.error(error1), .error(error2)):
      return error1.localizedDescription == error2.localizedDescription
    default:
      return false
    }
  }
}

/// Objective-C-only enum. Specifies the reason the paywall presentation was skipped.
@objc(SWKPaywallSkippedReason)
public enum PaywallSkippedReasonObjc: Int, Sendable, Equatable {
  /// The user was assigned to a holdout group.
  case holdout

  /// No rule was matched for this event.
  case noRuleMatch

  /// This event was not found on the dashboard.
  ///
  /// Please make sure you have added the event to a campaign on the dashboard and
  /// double check its spelling.
  case eventNotFound

  /// The user is subscribed.
  ///
  /// This means ``Superwall/subscriptionStatus`` is set to `.active`. If you're
  /// letting Superwall handle subscription-related logic, it will be based on the on-device
  /// receipts. Otherwise it'll be based on the value you've set.
  ///
  /// By default, paywalls do not show to users who are already subscribed. You can override this
  /// behavior in the paywall editor.
  case userIsSubscribed

  /// An error occurred.
  case error
}
