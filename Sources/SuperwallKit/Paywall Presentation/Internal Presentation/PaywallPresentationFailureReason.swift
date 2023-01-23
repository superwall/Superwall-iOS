//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/01/2023.
//

import Foundation

/// The reason to why the paywall couldn't present.
public enum PaywallPresentationFailureReason {
  /// Trying to present paywall when debugger is launched.
  case debuggerLaunched

  /// The user is already subscribed.
  case userIsSubscribed

  /// The user is in a holdout group.
  case holdout(Experiment)

  /// No rules defined in the campaign for the event matched.
  case noRuleMatch

  /// The event provided was not found in any campaign on the dashboard.
  case eventNotFound

  /// There was an error getting the paywall view controller.
  case noPaywallViewController(Error)

  /// There isn't a view to present the paywall on.
  case noPresenter(Error)

  /// There's already a paywall presented.
  case alreadyPresented(Error)
}
