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

  /// A trigger was not found for this event.
  ///
  /// Please make sure the trigger is enabled on the dashboard and you have the correct spelling of the event.
  case triggerNotFound

  /// An error occurred.
  case error(Error)
}
