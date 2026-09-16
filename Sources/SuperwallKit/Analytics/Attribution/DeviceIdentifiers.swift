//
//  DeviceIdentifiers.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 16/09/2026.
//

import Foundation

/// The identifiers the SDK owns in both the integration attributes and the
/// user's attributes: the vendor id, the advertising id, and the tracking
/// consent status that governs whether the advertising id exists.
///
/// Not to be confused with the device attributes behind
/// `Superwall.getDeviceAttributes()`, which describe the device and the session
/// rather than identify it.
enum DeviceIdentifiers {
  static let keys = ["idfa", "idfv", "attStatus"]

  /// The identifiers as the user's attributes should carry them.
  ///
  /// A missing identifier is sent as an explicit `NSNull()` rather than left
  /// out: `setUserAttributes` reads a Swift `nil` as "delete this key", which
  /// would leave the server holding the last value it saw. A null overwrites
  /// that, which is what clears an IDFA once consent is revoked.
  static func userAttributes(for identifiers: [String: String]) -> [String: Any?] {
    var userAttributes: [String: Any?] = [:]
    for key in keys {
      if let value = identifiers[key] {
        userAttributes[key] = value
      } else {
        userAttributes[key] = NSNull()
      }
    }
    return userAttributes
  }

  /// Whether a user-attribute value is the one last sent for that key.
  ///
  /// An identifier left out of the snapshot was sent as `NSNull()`, so a null
  /// agreeing with an absent identifier is a match, not an overwrite.
  static func isWhatWasSent(
    _ value: Any?,
    forKey key: String,
    in lastSynced: [String: String]
  ) -> Bool {
    if let sent = lastSynced[key] {
      return value as? String == sent
    }
    return value is NSNull
  }
}
