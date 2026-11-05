//
//  PrivateSuperwallEvents.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 27/10/2026.
//

import Foundation

/// An event the SDK sends to Superwall's servers and nowhere else.
///
/// Unlike a ``TrackableSuperwallEvent`` it isn't a ``SuperwallEvent``, so it
/// never reaches ``SuperwallDelegate/handleSuperwallEvent(withInfo:)-50exd``,
/// can't trigger a paywall and isn't stored on-device for audience filters.
/// Customers often forward every Superwall event to their own analytics, so
/// anything sensitive, such as a push token, must only travel in one of these.
///
/// Its ``Trackable/audienceFilterParams`` are sent with the event exactly as
/// they're keyed: unlike Superwall parameters they aren't given a `$` prefix,
/// and the events encoder leaves dictionary keys alone.
protocol PrivateSuperwallEvent: Trackable {}

extension PrivateSuperwallEvent {
  var canImplicitlyTriggerPaywall: Bool {
    return false
  }

  func getSuperwallParameters() async -> [String: Any] {
    return [:]
  }
}

enum PrivateSuperwallEvents {
  /// Reports the device's push token and notification permission, so
  /// Superwall can send the device notifications.
  ///
  /// The collector routes this by name to its own topic, keeping the token out
  /// of the analytics tables.
  struct NotificationToken: PrivateSuperwallEvent {
    static let name = "notification_token"

    let payload: NotificationTokenPayload

    var rawName: String {
      return Self.name
    }

    var audienceFilterParams: [String: Any] {
      return payload.parameters
    }
  }

  /// Tracked when the user opens a notification that Superwall sent.
  struct NotificationOpen: PrivateSuperwallEvent {
    static let name = "notification_open"

    let sendId: String
    let contactPointId: String?

    var rawName: String {
      return Self.name
    }

    var audienceFilterParams: [String: Any] {
      var parameters: [String: Any] = ["sendId": sendId]
      if let contactPointId = contactPointId {
        parameters["contactPointId"] = contactPointId
      }
      return parameters
    }
  }
}
