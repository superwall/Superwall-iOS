//
//  EventTrackingBehavior.swift
//
//
//  Created by Yusuf Tör on 22/06/2026.
//

import Foundation

/// Controls which events are sent to the Superwall servers.
///
/// Use ``SuperwallOptions/eventTrackingBehavior`` or set ``Superwall/eventTrackingBehavior``
/// at runtime to change event collection at any time.
///
/// - `.all`: All events are tracked (default).
/// - `.superwallOnly`: Only internal Superwall events are tracked. User-initiated
///   ``Superwall/track(event:params:)`` calls, trigger fires, and user-attribute updates
///   are suppressed. Equivalent to the deprecated `isExternalDataCollectionEnabled = false`.
/// - `.none`: No events are sent to the Superwall servers. Install-attribution
///   matching and enrichment are also skipped, so `acquisition_*` user attributes,
///   `demandScore` and `demandTier` won't populate and audience rules that rely on
///   them won't match. Use `.superwallOnly` if you need that targeting with
///   minimal tracking.
@objc(SWKEventTrackingBehavior)
public enum EventTrackingBehavior: Int, CustomStringConvertible, Encodable, Sendable {
  /// All events are tracked. This is the default.
  case all = 0

  /// Only internal Superwall events are tracked.
  ///
  /// User-initiated tracking calls, trigger-fire events, and user-attribute
  /// updates are suppressed. All other internal SDK events continue to be sent.
  case superwallOnly = 1

  /// No events are sent to the Superwall servers.
  ///
  /// Install-attribution matching is also skipped — it would otherwise post
  /// device metadata to the backend, bypassing the opt-out — and so are the
  /// public IP address lookups it uses. Because the match
  /// never runs, `acquisition_*` user attributes aren't populated, so audience
  /// rules that depend on them won't match.
  ///
  /// Enrichment is skipped too, since it posts the user and device attributes,
  /// so `demandScore` and `demandTier` aren't populated either. Use
  /// ``superwallOnly`` instead if you need attribution-based or demand-based
  /// targeting with minimal tracking.
  case none = 2

  public var description: String {
    switch self {
    case .all: return "all"
    case .superwallOnly: return "superwallOnly"
    case .none: return "none"
    }
  }
}
