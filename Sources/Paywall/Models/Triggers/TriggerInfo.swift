//
//  TriggerInfo.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

/// `ExperimentInfo` contains information describing the experiment and variant a given user was assigned. An experiment is a set of variants determined by probabilities. Currently experiements can only result in a user seeing a paywall or a user not seeing a paywall, known as a holdout.
struct ExperimentInfo {
    /// What experiement was found as a result of this trigger.
    public let experimentId: String
    /// What variant of that experiment was shown to a user.
    public let variantId: String
}

/// `TriggerResult` contains infromation for tracking the result of a trigger fire event. Triggers act as entrypoints in your applicaiton where you can conditionally show a paywall. This object contains infromation to tell you about what the result of that trigger was.
enum TriggerResult {
    /// No matching rule was found for this trigger, so nothing happened.
    case noRuleMatch
    /// A matching rule was found and this user was shown a paywall
    /// `experimentInfo` Information about the experiment that resulted in showing this paywall
    /// `paywallIdentifier` The identifier of the paywall that was shown to the user
    case paywall(experimentInfo: ExperimentInfo, paywallIdentifier: String)
    /// A matching rule was found and this user was assigned to a holdout group and was not shown a paywall
    /// `experimentInfo` Information about the experiment that resulted in not showing a paywall
    case holdout(experimentInfo: ExperimentInfo)
}
