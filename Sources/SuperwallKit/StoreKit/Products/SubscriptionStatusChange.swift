//
//  SubscriptionStatusChange.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-03.
//

import Foundation

/// What prompted a publish of ``Superwall/subscriptionStatus``.
///
/// The three cases are the only ways the published status can change, and
/// each carries exactly what that path knows: the two assignments carry a
/// new status, a grant change carries nothing because it leaves the assigned
/// status alone and only changes what merges into it.
enum SubscriptionStatusChange {
  /// The developer assigned ``Superwall/subscriptionStatus`` directly.
  case developerAssignment(SubscriptionStatus)

  /// The SDK assigned a status it worked out itself — device + web
  /// entitlements, the cold-launch restore, or test mode.
  case sdkAssignment(SubscriptionStatus)

  /// ``Superwall/grantedEntitlements`` changed, so the status is republished
  /// from the assigned value it already had.
  case grantChange
}
