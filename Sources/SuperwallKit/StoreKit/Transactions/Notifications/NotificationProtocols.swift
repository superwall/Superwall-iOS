//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/09/2023.
//

import Foundation
import UserNotifications

protocol NotificationSettings {
  var authorizationStatus: UNAuthorizationStatus { get }
}

extension UNNotificationSettings: NotificationSettings {}

protocol NotificationAuthorizable {
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
  func notificationSettings() async -> NotificationSettings
  func add(_ request: UNNotificationRequest) async throws
  func pendingNotificationRequests() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: NotificationAuthorizable {
  func notificationSettings() async -> NotificationSettings {
    await self.notificationSettings() as UNNotificationSettings
  }
}
