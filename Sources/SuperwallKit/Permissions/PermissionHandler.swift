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
  var locationDelegate: LocationPermissionDelegate?

  // Info.plist keys for each permission type
  enum PlistKey {
    static let camera = "NSCameraUsageDescription"
    static let photoLibrary = "NSPhotoLibraryUsageDescription"
    static let contacts = "NSContactsUsageDescription"
    static let locationWhenInUse = "NSLocationWhenInUseUsageDescription"
    static let locationAlways = "NSLocationAlwaysAndWhenInUseUsageDescription"
  }

  func hasPlistKey(_ key: String) -> Bool {
    return Bundle.main.object(forInfoDictionaryKey: key) != nil
  }

  func hasPermission(_ permission: PermissionType) async -> PermissionStatus {
    switch permission {
    case .notification:
      return await checkNotificationPermission()
    case .location:
      return checkLocationPermission()
    case .backgroundLocation:
      return checkBackgroundLocationPermission()
    case .readImages:
      return checkPhotosPermission()
    case .contacts:
      return checkContactsPermission()
    case .camera:
      return checkCameraPermission()
    }
  }

  func requestPermission(_ permission: PermissionType) async -> PermissionStatus {
    switch permission {
    case .notification:
      return await requestNotificationPermission()
    case .location:
      return await requestLocationPermission()
    case .backgroundLocation:
      return await requestBackgroundLocationPermission()
    case .readImages:
      return await requestPhotosPermission()
    case .contacts:
      return await requestContactsPermission()
    case .camera:
      return await requestCameraPermission()
    }
  }
}
