//
//  NotificationTokenStorage.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/11/2026.
//

import Foundation

/// The device's latest push token, its notification permission and whether
/// the app has opted it out of Superwall notifications.
///
/// Device-scoped, so it survives `reset()`: the token belongs to the install,
/// not the user, and the opt-out is the app's choice for the device. It's only
/// ever sent in a `notification_token` event, never as a user or device
/// attribute.
enum NotificationTokenStateStorage: Storable {
  static var key: String {
    "store.notificationTokenState"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = NotificationTokenState
}

/// A fingerprint of the last `notification_token` event sent and when it was
/// sent, so an unchanged state is only re-sent once a day.
enum NotificationTokenLastSentStorage: Storable {
  static var key: String {
    "store.notificationTokenLastSent"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = NotificationTokenLastSent
}

/// Notification opens that arrived before config, kept so they're still
/// counted if config only arrives on a later launch.
enum NotificationHeldOpensStorage: Storable {
  static var key: String {
    "store.notificationHeldOpens"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = [PrivateSuperwallEvents.NotificationOpen]
}
