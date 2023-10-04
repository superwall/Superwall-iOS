//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/06/2023.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
  static let superwallIdentifier = "com.superwall.ios"

  private static func askForPermissionsIfNecessary(
    using notificationCenter: NotificationAuthorizable
  ) async -> Bool {
    if await checkIsAuthorized(using: notificationCenter) {
      return true
    }

    return await withCheckedContinuation { continuation in
      notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { isAuthorized, _ in
        if isAuthorized {
          return continuation.resume(returning: true)
        } else {
          return continuation.resume(returning: false)
        }
      }
    }
  }

  static func scheduleNotifications(
    _ notifications: [LocalNotification],
    factory: DeviceHelperFactory,
    notificationCenter: NotificationAuthorizable = UNUserNotificationCenter.current()
  ) async {
    if notifications.isEmpty {
      return
    }
    guard await NotificationScheduler.askForPermissionsIfNecessary(using: notificationCenter) else {
      return
    }

    await withTaskGroup(of: Void.self) { taskGroup in
      for notification in notifications {
        taskGroup.addTask {
          await scheduleNotification(notification, factory: factory, notificationCenter: notificationCenter)
        }
      }
    }
  }

  private static func scheduleNotification(
    _ notification: LocalNotification,
    factory: DeviceHelperFactory,
    notificationCenter: NotificationAuthorizable
  ) async {
    let content = UNMutableNotificationContent()
    content.title = notification.title
    content.subtitle = notification.subtitle ?? ""
    content.body = notification.body

    var delay = notification.delay / 1000

    let isSandbox = factory.makeIsSandbox()
    if isSandbox {
      delay = delay / 24 / 60
    }

    // Show this notification X seconds from now.
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: delay,
      repeats: false
    )

    // Choose a random identifier
    let request = UNNotificationRequest(
      identifier: superwallIdentifier + "-" + UUID().uuidString,
      content: content,
      trigger: trigger
    )

    // Add our notification request
    do {
      try await notificationCenter.add(request)
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Could not schedule notification with title \(notification.title)"
      )
    }
  }

  private static func checkIsAuthorized(using notificationCenter: NotificationAuthorizable) async -> Bool {
    return await withCheckedContinuation { continuation in
      notificationCenter.getSettings { settings in
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
