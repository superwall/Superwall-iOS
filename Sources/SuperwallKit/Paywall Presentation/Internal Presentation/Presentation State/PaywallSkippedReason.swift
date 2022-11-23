//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/09/2022.
//

import Foundation

/// The reason the paywall presentation was skipped.
public enum PaywallSkippedReason {
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
  /// The value returned in the ``SuperwallDelegate/isUserSubscribed()`` delegate
  /// method is `true`. By default, paywalls do not show to users who are already subscribed.
  ///
  /// You can override this behavior in the paywall editor.
  case userIsSubscribed

  /// An error occurred.
  case error(Error)
}

/// Objective-C compatible enum for ``PaywallDismissedResult/DismissState``
/// The reason the paywall presentation was skipped.
@objc(SWKPaywallSkippedReason)
public enum PaywallSkippedReasonObjc: Int {
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
  /// The value returned in the ``SuperwallDelegateObjc/isUserSubscribed()`` delegate
  /// method is `true`. Therefore, a paywall will not show.
  case userIsSubscribed

  /// An error occurred.
  case error
}
