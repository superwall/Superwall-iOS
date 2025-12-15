//
//  UserPermissionsImpl.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import Foundation
import UserNotifications

/// Default implementation of UserPermissions using system frameworks.
final class UserPermissionsImpl: UserPermissions {
  private let notificationCenter: UNUserNotificationCenter

  init(notificationCenter: UNUserNotificationCenter = .current()) {
    self.notificationCenter = notificationCenter
  }

  func hasPermission(_ permission: PermissionType) async -> PermissionStatus {
    switch permission {
    case .notification:
      return await checkNotificationPermission()
    }
  }

  func requestPermission(_ permission: PermissionType) async -> PermissionStatus {
    switch permission {
    case .notification:
      return await requestNotificationPermission()
    }
  }

  // MARK: - Notification Permission

  private func checkNotificationPermission() async -> PermissionStatus {
    let settings = await notificationCenter.notificationSettings()
    return mapNotificationAuthorizationStatus(settings.authorizationStatus)
  }

  private func requestNotificationPermission() async -> PermissionStatus {
    do {
      let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
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

  private func mapNotificationAuthorizationStatus(
    _ status: UNAuthorizationStatus
  ) -> PermissionStatus {
    switch status {
    case .authorized, .provisional, .ephemeral:
      return .granted
    case .denied:
      return .denied
    case .notDetermined:
      // Not determined means we haven't asked yet, treat as not granted
      return .denied
    @unknown default:
      return .unsupported
    }
  }
}
