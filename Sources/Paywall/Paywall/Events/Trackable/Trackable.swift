//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation

/// A protocol that defines an event that is trackable.
protocol Trackable {
  /// The string representation of the name.
  ///
  /// For  a `TrackableSuperwallEvent`,  this is the raw value of an ``Paywall/Paywall/EventName`` assigned to it.
  var rawName: String { get }
  /// Parameters that are marked with a $ when sent back to the server to be recognised as Superwall parameters.
  var superwallParameters: [String: Any]? { get }
  /// Determines whether the event has the potential to trigger a paywall. Defaults to true.
  var canTriggerPaywall: Bool { get }
}

// The default Trackable implementation, that has no parameters and can trigger a paywall.
extension Trackable {
  var superwallParameters: [String: Any]? {
    return nil
  }

  var canTriggerPaywall: Bool {
    return true
  }
}
