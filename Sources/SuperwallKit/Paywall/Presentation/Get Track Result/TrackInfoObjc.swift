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
@objc(SWKTrackResult)
public enum TrackResultObjc: Int, Sendable, Equatable {
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

  /// An error occurred and the user will not be shown a paywall.
  case error
}

/// Information about the result of tracking an event.
@objc(SWKTrackInfo)
@objcMembers
public final class TrackInfoObjc: NSObject, Sendable {
  /// The result of tracking an event.
  public let result: TrackResultObjc

  /// A campaign experiment that was assigned to a user.
  ///
  /// This is non-`nil` when the `result` is a `holdout` or
  /// a `paywall`.
  public let experiment: Experiment?

  /// The error returned when the `result` is an `error`.
  public let error: NSError?

  init(trackResult: TrackResult) {
    switch trackResult {
    case .paywall(let experiment):
      self.result = .paywall
      self.experiment = experiment
      self.error = nil
    case .error(let error):
      self.result = .error
      self.experiment = nil
      self.error = error
    case .eventNotFound:
      self.result = .eventNotFound
      self.experiment = nil
      self.error = nil
    case .holdout(let experiment):
      self.result = .holdout
      self.experiment = experiment
      self.error = nil
    case .noRuleMatch:
      self.result = .noRuleMatch
      self.experiment = nil
      self.error = nil
    }
  }
}
