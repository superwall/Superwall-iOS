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
  case eventNotFound
  case noRuleMatch
  case paywall
  case holdout
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
