//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/06/2023.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
  private static func askForPermissionsIfNecessary() async -> Bool {
    if await checkIsAuthorized() {
      return true
    }

    let center = UNUserNotificationCenter.current()

    return await withCheckedContinuation { continuation in
      center.requestAuthorization(options: [.alert, .sound, .badge]) { isAuthorized, _ in
        if isAuthorized {
          return continuation.resume(returning: true)
        } else {
          return continuation.resume(returning: false)
        }
      }
    }
  }

  static func scheduleNotifications(_ notifications: [LocalNotification]) async {
    if notifications.isEmpty {
      return
    }
    guard await NotificationScheduler.askForPermissionsIfNecessary() else {
      return
    }

    await withTaskGroup(of: Void.self) { taskGroup in
      for notification in notifications {
        taskGroup.addTask {
          await scheduleNotification(notification)
        }
      }
    }
  }

  private static func scheduleNotification(_ notification: LocalNotification) async {
    let content = UNMutableNotificationContent()
    content.title = notification.title
    content.subtitle = notification.subtitle ?? ""
    content.body = notification.body

    // Show this notification X seconds from now.
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: notification.delay / 1000,
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

  private static func checkIsAuthorized() async -> Bool {
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
