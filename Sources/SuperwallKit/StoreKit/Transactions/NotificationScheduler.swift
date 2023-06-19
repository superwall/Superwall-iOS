//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/06/2023.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
  static func scheduleNotification(_ notification: LocalNotification) async {
    guard await checkIsAuthorized() else {
      return
    }

    let content = UNMutableNotificationContent()
    content.title = notification.title
    content.subtitle = notification.subtitle ?? ""

    // Show this notification X seconds from now.
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: notification.delay * 1000,
      repeats: false
    )

    // Choose a random identifier
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: trigger
    )

    // Add our notification request
    do {
      try await UNUserNotificationCenter.current().add(request)
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Could not schedule notification with title \(notification.title)"
      )
    }
  }

  static func checkIsAuthorized() async -> Bool {
    return await withCheckedContinuation { continuation in
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        switch settings.authorizationStatus {
        case .authorized,
          .ephemeral,
          .provisional:
          continuation.resume(returning: true)
        default:
          continuation.resume(returning: false)
        }
      }
    }
  }
}
