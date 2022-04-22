//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation

protocol TrackableUserInitiatedEvent: Trackable {}

/// These are events that are initiated by the user. Unlike `SuperwallTrackableEvents`, they are not sent back to the delegate.
enum UserInitiatedEvent {
  struct Attributes: TrackableUserInitiatedEvent {
    let rawName = "user_attributes"
    let superwallParameters: [String : Any]? = [
      "application_installed_at": DeviceHelper.shared.appInstallDate
    ]
    let canTriggerPaywall = false
  }

  struct Track: TrackableUserInitiatedEvent {
    let rawName: String
    let superwallParameters: [String : Any]? = nil
    let canTriggerPaywall: Bool
  }

  struct DeepLink: TrackableUserInitiatedEvent {
    let rawName = "deepLink_open"
    let url: URL
    var superwallParameters: [String : Any]? {
      return ["url": url.absoluteString]
    }
  }

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
    var superwallParameters: [String : Any]? {
      if let pushNotificationId = pushNotificationId {
        return ["push_notification_id": pushNotificationId]
      }
      return nil
    }
    let state: State
    let pushNotificationId: String?
  }
}
