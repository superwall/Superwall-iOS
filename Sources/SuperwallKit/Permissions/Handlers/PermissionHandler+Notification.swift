//
//  PermissionHandler+Notification.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import UserNotifications

extension PermissionHandler {
  func checkNotificationPermission() async -> PermissionStatus {
    let settings: UNNotificationSettings = await notificationCenter.notificationSettings()
    return settings.authorizationStatus.toPermissionStatus
  }

  func requestNotificationPermission() async -> PermissionStatus {
    do {
      let granted = try await notificationCenter.requestAuthorization(
        options: [.alert, .badge, .sound]
      )
      return granted ? .granted : .denied
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Error requesting notification permission",
        error: error
      )
      return .denied
    }
  }
}
