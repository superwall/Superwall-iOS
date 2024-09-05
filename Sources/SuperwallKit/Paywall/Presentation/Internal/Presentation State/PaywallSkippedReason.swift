//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/09/2022.
//

import Foundation

/// The reason the paywall presentation was skipped.
public enum PaywallSkippedReason: Error, Sendable, Equatable, CustomStringConvertible {
  /// The user was assigned to a holdout.
  ///
  /// A holdout is a control group which you can analyse against
  /// who don't receive any paywall when they match an audience.
  ///
  /// It's useful for testing a paywall's inclusion vs its exclusion.
  case holdout(Experiment)

  /// No audience was matched for this placement.
  case noAudienceMatch

  /// This placement was not found on the dashboard.
  ///
  /// Please make sure you have added the placement to a campaign on the dashboard and
  /// double check its spelling.
  case placementNotFound

  /// The user is subscribed.
  ///
  /// This means ``Superwall/subscriptionStatus`` is set to `.active`. If you're
  /// letting Superwall handle subscription-related logic, it will be based on the on-device
  /// receipts. Otherwise it'll be based on the value you've set.
  ///
  /// By default, paywalls do not show to users who are already subscribed. You can override this
  /// behavior in the paywall editor.
  case userIsSubscribed

  public var description: String {
    switch self {
    case .placementNotFound:
      return "The paywall was skipped because the placement is not part of a campaign."
    case .holdout:
      return "The paywall was skipped because the user is part of a holdout."
    case .noAudienceMatch:
      return "The paywall was skipped because the user doesn't match any audiences."
    case .userIsSubscribed:
      return "The paywall was skipped because the user is subscribed."
    }
  }

  public static func == (lhs: PaywallSkippedReason, rhs: PaywallSkippedReason) -> Bool {
    switch (lhs, rhs) {
    case (.noAudienceMatch, .noAudienceMatch),
      (.placementNotFound, .placementNotFound),
      (.userIsSubscribed, .userIsSubscribed):
      return true
    case let (.holdout(experiment1), .holdout(experiment2)):
      return experiment1 == experiment2
    default:
      return false
    }
  }

  func toObjc() -> PaywallSkippedReasonObjc {
    switch self {
    case .holdout:
      return .holdout
    case .noAudienceMatch:
      return .noAudienceMatch
    case .placementNotFound:
      return .placementNotFound
    case .userIsSubscribed:
      return .userIsSubscribed
    }
  }
}

/// Objective-C-only enum. Specifies the reason the paywall presentation was skipped.
@objc(SWKPaywallSkippedReason)
public enum PaywallSkippedReasonObjc: Int, Error, Sendable, Equatable, CustomStringConvertible {
  /// The user was assigned to a holdout group.
  case holdout

  /// No audience was matched for this placement.
  case noAudienceMatch

  /// This placement was not found on the dashboard.
  ///
  /// Please make sure you have added the placement to a campaign on the dashboard and
  /// double check its spelling.
  case placementNotFound

  /// The user is subscribed.
  ///
  /// This means ``Superwall/subscriptionStatus`` is set to `.active`. If you're
  /// letting Superwall handle subscription-related logic, it will be based on the on-device
  /// receipts. Otherwise it'll be based on the value you've set.
  ///
  /// By default, paywalls do not show to users who are already subscribed. You can override this
  /// behavior in the paywall editor.
  case userIsSubscribed

  /// The presentation wasn't skipped.
  case none

  public var description: String {
    switch self {
    case .placementNotFound:
      return "The paywall was skipped because the placement is not part of a campaign."
    case .holdout:
      return "The paywall was skipped because the user is part of a holdout."
    case .noAudienceMatch:
      return "The paywall was skipped because the user doesn't match any audiences."
    case .userIsSubscribed:
      return "The paywall was skipped because the user is subscribed."
    case .none:
      return "The paywall was not skipped."
    }
  }
}
