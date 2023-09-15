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
  func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void)
  func getSettings(completionHandler: @escaping (NotificationSettings) -> Void)
  func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationAuthorizable {
  func getSettings(completionHandler: @escaping (NotificationSettings) -> Void) {
    getNotificationSettings(completionHandler: completionHandler)
  }
}
