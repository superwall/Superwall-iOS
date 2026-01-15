//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/06/2023.
//

import UIKit
import UserNotifications

actor NotificationScheduler {
  static let shared = NotificationScheduler()
  static let superwallIdentifier = "com.superwall.ios"
  private var isScheduling = false

  private func askForPermissionsIfNecessary(
    using notificationCenter: NotificationAuthorizable
  ) async -> Bool {
    if await Self.checkIsAuthorized(using: notificationCenter) {
      return true
    }

    do {
      return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      return false
    }
  }

  func scheduleNotifications(
    _ notifications: [LocalNotification],
    fromPaywallId paywallId: String,
    factory: DeviceHelperFactory,
    notificationCenter: NotificationAuthorizable = UNUserNotificationCenter.current()
  ) async {
    if notifications.isEmpty {
      return
    }

    // Prevent concurrent scheduling which could show duplicate alerts
    if isScheduling {
      return
    }
    isScheduling = true
    defer { isScheduling = false }

    // Filter out notifications that are already scheduled
    let pendingIdentifiers = await Self.getPendingNotificationIdentifiers(using: notificationCenter)
    let notificationsToSchedule = notifications.filter { notification in
      let identifier = Self.makeNotificationIdentifier(paywallId: paywallId, type: notification.type)
      return !pendingIdentifiers.contains(identifier)
    }

    if notificationsToSchedule.isEmpty {
      return
    }

    guard await askForPermissionsIfNecessary(using: notificationCenter) else {
      if let notificationPermissionsDenied = Superwall.shared.options.paywalls.notificationPermissionsDenied {
        await withCheckedContinuation { continuation in
          Task { @MainActor in
            Superwall.shared.paywallViewController?.presentAlert(
              title: notificationPermissionsDenied.title,
              message: notificationPermissionsDenied.message,
              actionTitle: notificationPermissionsDenied.actionButtonTitle,
              closeActionTitle: notificationPermissionsDenied.closeButtonTitle,
              action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                  guard let sharedApplication = UIApplication.sharedApplication else {
                    return continuation.resume()
                  }
                  sharedApplication.open(url)
                }
                continuation.resume()
              },
              onClose: {
                continuation.resume()
              }
            )
          }
        }
      }
      return
    }

    for notification in notificationsToSchedule {
      await Self.scheduleNotification(
        notification,
        paywallId: paywallId,
        factory: factory,
        notificationCenter: notificationCenter
      )
    }
  }

  private static func scheduleNotification(
    _ notification: LocalNotification,
    paywallId: String,
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

    guard delay > 0 else {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Notification delay isn't greater than 0 seconds. Notifications will not be scheduled."
      )
      return
    }

    // Show this notification X seconds from now.
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: delay,
      repeats: false
    )

    // Use deterministic identifier based on paywall and notification type
    let identifier = makeNotificationIdentifier(paywallId: paywallId, type: notification.type)
    let request = UNNotificationRequest(
      identifier: identifier,
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

  private static func makeNotificationIdentifier(
    paywallId: String,
    type: LocalNotificationType
  ) -> String {
    return "\(superwallIdentifier)-\(paywallId)-\(type.description)"
  }

  private static func getPendingNotificationIdentifiers(
    using notificationCenter: NotificationAuthorizable
  ) async -> Set<String> {
    let requests = await notificationCenter.pendingNotificationRequests()
    return Set(requests.map { $0.identifier })
  }

  private static func checkIsAuthorized(using notificationCenter: NotificationAuthorizable) async -> Bool {
    let settings = await notificationCenter.notificationSettings()
    switch settings.authorizationStatus {
    case .authorized,
      .ephemeral:
      return true
    default:
      return false
    }
  }
}
