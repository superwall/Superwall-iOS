//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation

protocol TrackableUserInitiatedEvent: Trackable {}

enum UserInitiatedEvent {
  struct Attributes: TrackableUserInitiatedEvent {
    let name = "user_attributes"
    let parameters: [String : Any]? = [
      "application_installed_at": DeviceHelper.shared.appInstallDate
    ]
    let canTriggerPaywall = false
  }

  struct Track: TrackableUserInitiatedEvent {
    let name: String
    let parameters: [String : Any]? = nil
    let canTriggerPaywall: Bool
  }

  struct DeepLink: TrackableUserInitiatedEvent {
    let name = "deepLink_open"
    let url: URL
    var parameters: [String : Any]? {
      return ["url": url.absoluteString]
    }
  }

  // MARK: - To be deprecated/deleted
  struct PushNotification: TrackableUserInitiatedEvent {
    enum State {
      case receive
      case open
    }
    var name: String {
      switch state {
      case .open:
        return "pushNotification_open"
      case .receive:
        return "pushNotification_receive"
      }
    }
    var parameters: [String : Any]? {
      if let pushNotificationId = pushNotificationId {
        return ["push_notification_id": pushNotificationId]
      }
      return nil
    }
    let state: State
    let pushNotificationId: String?
  }
}
