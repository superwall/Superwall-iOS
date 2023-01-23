//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/11/2022.
//

import Foundation

/// The result of a tracking an event.
///
/// Contains the possible cases resulting from tracking an event.
public typealias TrackResult = TriggerResult

/// The result of a paywall trigger.
///
/// Triggers can conditionally show paywalls. Contains the possible cases resulting from the trigger.
public enum TriggerResult: Sendable, Equatable {
  /// This event was not found on the dashboard.
  ///
  /// Please make sure you have added the event to a campaign on the dashboard and
  /// double check its spelling.
  case eventNotFound

  /// No matching rule was found for this trigger so no paywall will be shown.
  case noRuleMatch

  /// A matching rule was found and this user will be shown a paywall.
  ///
  /// - Parameters:
  ///   - experiment: The experiment associated with the trigger.
  case paywall(Experiment)

  /// A matching rule was found and this user was assigned to a holdout group so will not be shown a paywall.
  ///
  /// - Parameters:
  ///   - experiment: The experiment  associated with the trigger.
  case holdout(Experiment)

  /// An error occurred and the user will not be shown a paywall.
  ///
  /// If the error code is `101`, it means that no view controller could be found to present on. Otherwise a network failure may have occurred.
  ///
  /// In these instances, consider fallng back to a native paywall.
  case error(NSError)
}
