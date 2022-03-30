//
//  TriggerInfo.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

/// A trigger experiment that was assigned to a user.
///
/// An experiment is a set of variants determined by probabilities. Experiments can only result in a user seeing a paywall or a user not seeing a paywall, known as a holdout.
struct Experiment {
  /// The id of the experiment.
  let id: String
  /// The id of the experiment variant.
  let variantId: String
}

/// The result of a trigger.
///
/// Triggers can conditionally show paywalls. Contains the possible cases resulting from the trigger.
enum TriggerResult {
  /// No matching rule was found for this trigger, so nothing happens.
  case noRuleMatch

  /// A matching rule was found and this user was shown a paywall
  ///
  /// - Parameters:
  ///   - experiment: The experiment associated with the trigger
  ///   - paywallIdentifier: The identifier of the paywall that was shown to the user
  case paywall(experiment: Experiment, paywallIdentifier: String)

  /// A matching rule was found and this user was assigned to a holdout group so was not shown a paywall.
  ///
  /// - Parameters:
  ///   - experiment: The experiment  associated with the trigger
  case holdout(experiment: Experiment)
}
