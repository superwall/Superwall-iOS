//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/09/2022.
//

import Foundation

/// The reason the paywall presentation was skipped.
public enum PaywallSkippedReason {
  /// The user was assigned to a holdout group.
  case holdout(Experiment)

  /// No rule was matched for this event.
  case noRuleMatch

  /// This event was not found on the dashboard.
  ///
  /// Please make sure you have added the event to a campaign on the dashboard and
  /// double check its spelling.
  case eventNotFound

  /// An error occurred.
  case error(Error)
}

/// Objective-C compatible enum for `PaywallDismissedResult.DismissState`
@objc(SWKPaywallSkippedReason)
public enum PaywallSkippedReasonObjc: Int {
    case holdout
    case noRuleMatch
    case eventNotFound
    case error
}
