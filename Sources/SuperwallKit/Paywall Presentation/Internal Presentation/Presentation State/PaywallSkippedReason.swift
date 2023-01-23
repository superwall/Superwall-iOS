//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/09/2022.
//

import Foundation

/// The reason the paywall presentation was skipped.
public enum PaywallSkippedReason: Sendable {
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
  /// If you're letting SuperwallKit handle subscription-related logic, this means that the user has
  /// an active purchase.
  ///
  /// If you're returning a ``SubscriptionController`` in the delegate, this means your
  /// ``SubscriptionController/isUserSubscribed()`` method is returning `true`.
  ///
  /// By default, paywalls do not show to users who are already subscribed. You can override this
  /// behavior in the paywall editor.
  case userIsSubscribed

  /// An error occurred.
  case error(Error)
}

/// Objective-C compatible enum for ``PaywallDismissedResult/DismissState``
/// The reason the paywall presentation was skipped.
@objc(SWKPaywallSkippedReason)
public enum PaywallSkippedReasonObjc: Int, Sendable {
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
  /// If you're letting SuperwallKit handle subscription-related logic, this means that the user has
  /// an active purchase.
  ///
  /// If you're returning a ``SubscriptionController`` in the delegate, this means your
  /// ``SubscriptionController/isUserSubscribed()`` method is returning `true`.
  ///
  /// By default, paywalls do not show to users who are already subscribed. You can override this
  /// behavior in the paywall editor.
  case userIsSubscribed

  /// An error occurred.
  case error
}
