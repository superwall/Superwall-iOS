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
/// - `.none`: No events are sent to the Superwall servers.
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
  case none = 2

  public var description: String {
    switch self {
    case .all: return "all"
    case .superwallOnly: return "superwallOnly"
    case .none: return "none"
    }
  }
}
