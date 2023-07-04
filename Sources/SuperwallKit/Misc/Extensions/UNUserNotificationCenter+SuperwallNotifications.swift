//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/07/2023.
//

import Foundation
import UserNotifications

public extension UNUserNotificationCenter {
  /// Removes all of Superwall's pending local notifications.
  ///
  /// This method executes asynchronously, removing all pending notification requests on a secondary thread.
  @objc
  func removeAllPendingSuperwallNotificationRequests() {
    Task {
      let allPendingNotifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
      let superwallIds = allPendingNotifications.compactMap {
        $0.identifier.contains(NotificationScheduler.superwallIdentifier) ? $0.identifier : nil
      }

      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: superwallIds)
    }
  }

  /// Removes all of your app's pending local notifications, except for those scheduled by Superwall.
  ///
  /// This method executes asynchronously, removing all pending notification requests on a secondary thread.
  @objc
  func removeAllPendingNonSuperwallNotificationRequests() {
    Task {
      let allPendingNotifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
      let nonSuperwallIds = allPendingNotifications.compactMap {
        $0.identifier.contains(NotificationScheduler.superwallIdentifier) ? nil : $0.identifier
      }

      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: nonSuperwallIds)
    }
  }

  /// Removes all of Superwall's delivered notifications from Notification Center.
  ///
  /// Use this method to remove all of your app’s delivered notifications from Notification Center while keeping Superwall's
  /// notifications visible. The method executes asynchronously, returning immediately and removing the identifiers on a
  /// background thread. This method does not affect any notification requests that are scheduled, but have not yet been delivered.
  @objc
  func removeAllDeliveredSuperwallNotifications() {
    Task {
      let allDeliveredNotifications = await UNUserNotificationCenter.current().deliveredNotifications()
      let superwallIds = allDeliveredNotifications.compactMap {
        $0.request.identifier.contains(NotificationScheduler.superwallIdentifier) ? $0.request.identifier : nil
      }

      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: superwallIds)
    }
  }

  /// Removes all of your app’s delivered notifications from Notification Center, except for those belonging to Superwall.
  ///
  /// Use this method to remove all of your app’s delivered notifications from Notification Center while keeping Superwall's
  /// notifications visible. The method executes asynchronously, returning immediately and removing the identifiers on a
  /// background thread. This method does not affect any notification requests that are scheduled, but have not yet been delivered.
  @objc
  func removeAllDeliveredNonSuperwallNotifications() {
    Task {
      let allDeliveredNotifications = await UNUserNotificationCenter.current().deliveredNotifications()
      let nonSuperwallIds = allDeliveredNotifications.compactMap {
        $0.request.identifier.contains(NotificationScheduler.superwallIdentifier) ? nil : $0.request.identifier
      }

      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: nonSuperwallIds)
    }
  }
}
