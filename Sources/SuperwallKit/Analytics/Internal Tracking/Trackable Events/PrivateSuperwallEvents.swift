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
protocol PrivateSuperwallEvent: Trackable {
  /// Whether the event is still sent while `eventTrackingBehavior` is `.none`.
  ///
  /// Only for an event that makes Superwall do less with the device, such as
  /// an opt-out of notifications. Defaults to `false`.
  var isSentWhenTrackingIsOff: Bool { get }

  /// When what the event reports happened, if that's earlier than when it's
  /// tracked. It becomes the event's `created_at`. Defaults to `nil`.
  var occurredAt: Date? { get }
}

extension PrivateSuperwallEvent {
  var isSentWhenTrackingIsOff: Bool {
    return false
  }

  var occurredAt: Date? {
    return nil
  }

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
    /// `true` only for an opt-out of a token Superwall already has opted in:
    /// it stops Superwall sending to the device and tells it nothing new.
    let isSentWhenTrackingIsOff: Bool

    init(
      payload: NotificationTokenPayload,
      isSentWhenTrackingIsOff: Bool = false
    ) {
      self.payload = payload
      self.isSentWhenTrackingIsOff = isSentWhenTrackingIsOff
    }

    var rawName: String {
      return Self.name
    }

    var audienceFilterParams: [String: Any] {
      return payload.parameters
    }
  }

  /// Tracked when the user opens a notification that Superwall sent.
  struct NotificationOpen: PrivateSuperwallEvent, Codable, Equatable {
    static let name = "notification_open"

    let sendId: String
    let contactPointId: String?
    /// When the user opened the notification. The open can be sent later than
    /// this, once config has arrived.
    let openedAt: Date

    var rawName: String {
      return Self.name
    }

    var occurredAt: Date? {
      return openedAt
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
