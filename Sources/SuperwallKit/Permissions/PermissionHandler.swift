//
//  PermissionHandler.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import CoreLocation
import Foundation
import UserNotifications

final class PermissionHandler: PermissionHandling {
  lazy var notificationCenter = UNUserNotificationCenter.current()
  lazy var locationManager = CLLocationManager()

  // Info.plist keys for each permission type
  enum PlistKey {
    static let camera = "NSCameraUsageDescription"
    static let photoLibrary = "NSPhotoLibraryUsageDescription"
  }

  func hasPlistKey(_ key: String) -> Bool {
    return Bundle.main.object(forInfoDictionaryKey: key) != nil
  }

  func hasPermission(_ permission: PermissionType) async -> PermissionStatus {
    switch permission {
    case .notification:
      return await checkNotificationPermission()
    case .location:
      return .unsupported
    case .backgroundLocation:
      return .unsupported
    case .readImages:
      return checkPhotosPermission()
    case .contacts:
      return .unsupported
    case .camera:
      return checkCameraPermission()
    }
  }

  func requestPermission(_ permission: PermissionType) async -> PermissionStatus {
    switch permission {
    case .notification:
      return await requestNotificationPermission()
    case .location:
      return .unsupported
    case .backgroundLocation:
      return .unsupported
    case .readImages:
      return await requestPhotosPermission()
    case .contacts:
      return .unsupported
    case .camera:
      return await requestCameraPermission()
    }
  }
}
