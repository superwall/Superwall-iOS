//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/09/2022.
//

import Foundation

/// The current state of a paywall.
public enum PaywallState {
  /// The paywall was presented. Contains a ``PaywallInfo`` object with more information about the presented paywall.
  case presented(PaywallInfo)

  /// The paywall was dismissed. Contains a ``PaywallDismissedResult`` object that contains information about the
  /// paywall and why it was dismissed.
  case dismissed(PaywallDismissedResult)

  /// The paywall was skipped. Contains a ``PaywallSkippedReason`` enum whose cases state why the paywall was skipped.
  case skipped(PaywallSkippedReason)
}
