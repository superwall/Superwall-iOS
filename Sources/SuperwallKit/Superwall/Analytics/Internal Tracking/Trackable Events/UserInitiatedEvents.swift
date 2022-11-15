//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//
// swiftlint:disable:all nesting

import Foundation

protocol TrackableUserInitiatedEvent: Trackable {}

/// These are events that are initiated by the user. Unlike `SuperwallTrackableEvents`, they are not sent back to the delegate.
enum UserInitiatedEvent {
  struct Track: TrackableUserInitiatedEvent {
    let rawName: String
    let canImplicitlyTriggerPaywall: Bool
    var customParameters: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] { [:] }
  }

  struct DefaultPaywall: TrackableUserInitiatedEvent {
    let rawName = "$present"
    let canImplicitlyTriggerPaywall = false
    let customParameters: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] { [:] }
  }
  /*
  // TODO: Check over this
  // MARK: - To be deprecated/deleted
  struct PushNotification: TrackableUserInitiatedEvent {
    enum State {
      case receive
      case open
    }
    var rawName: String {
      switch state {
      case .open:
        return "pushNotification_open"
      case .receive:
        return "pushNotification_receive"
      }
    }
    func getSuperwallParameters() async -> [String: Any] {
      if let pushNotificationId = pushNotificationId {
        return ["push_notification_id": pushNotificationId]
      }
      return [:]
    }
    let state: State
    let pushNotificationId: String?
    let canImplicitlyTriggerPaywall = true
    var customParameters: [String: Any] = [:]
  }*/
}
