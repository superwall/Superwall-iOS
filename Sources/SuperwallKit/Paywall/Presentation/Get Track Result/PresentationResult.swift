//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/03/2023.
//

import Foundation

/// The result of a tracking an event.
///
/// Contains the possible cases resulting from tracking an event.
public enum PresentationResult: Sendable, Equatable {
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

  /// The user is subscribed.
  ///
  /// This means ``Superwall/subscriptionStatus`` is set to `.active`. If you're
  /// letting Superwall handle subscription-related logic, it will be based on the on-device
  /// receipts. Otherwise it'll be based on the value you've set.
  ///
  /// By default, paywalls do not show to users who are already subscribed. You can override this
  /// behavior in the paywall editor.
  case userIsSubscribed

  /// No view controller could be found to present on.
  case paywallNotAvailable
}
