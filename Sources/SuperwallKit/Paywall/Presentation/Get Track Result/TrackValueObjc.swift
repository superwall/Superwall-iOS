//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/11/2022.
//

import Foundation

/// The result of tracking an event.
///
/// Contains the possible cases resulting from tracking an event.
@objc(SWKTrackValue)
public enum TrackValueObjc: Int, Sendable, Equatable {
  /// This event was not found on the dashboard.
  ///
  /// Please make sure you have added the event to a campaign on the dashboard and
  /// double check its spelling.
  case eventNotFound

  /// No matching rule was found for this trigger so no paywall will be shown.
  case noRuleMatch

  /// A matching rule was found and this user will be shown a paywall.
  case paywall

  /// A matching rule was found and this user was assigned to a holdout group so will not be shown a paywall.
  case holdout

  /// No view controller could be found to present on.
  case paywallNotAvailable

  /// The user is subscribed.
  ///
  /// This means ``Superwall/subscriptionStatus`` is set to `.active`. If you're
  /// letting Superwall handle subscription-related logic, it will be based on the on-device
  /// receipts. Otherwise it'll be based on the value you've set.
  ///
  /// By default, paywalls do not show to users who are already subscribed. You can override this
  /// behavior in the paywall editor.
  case userIsSubscribed
}

/// Information about the result of tracking an event.
@objc(SWKTrackResult)
@objcMembers
public final class TrackResultObjc: NSObject, Sendable {
  /// The result of tracking an event.
  public let value: TrackValueObjc

  /// A campaign experiment that was assigned to a user.
  ///
  /// This is non-`nil` when the `result` is a `holdout` or
  /// a `paywall`.
  public let experiment: Experiment?

  init(trackResult: TrackResult) {
    switch trackResult {
    case .paywall(let experiment):
      self.value = .paywall
      self.experiment = experiment
    case .eventNotFound:
      self.value = .eventNotFound
      self.experiment = nil
    case .holdout(let experiment):
      self.value = .holdout
      self.experiment = experiment
    case .noRuleMatch:
      self.value = .noRuleMatch
      self.experiment = nil
    case .userIsSubscribed:
      self.value = .userIsSubscribed
      self.experiment = nil
    case .paywallNotAvailable:
      self.value = .paywallNotAvailable
      self.experiment = nil
    }
  }
}
