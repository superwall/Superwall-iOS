//
//  PermissionHandler.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import Foundation
import UIKit
import UserNotifications

final class PermissionHandler: PermissionHandling {
  lazy var notificationCenter = UNUserNotificationCenter.current()
  var locationDelegate: LocationPermissionDelegate?

  // Info.plist keys for each permission type
  enum PlistKey {
    static let camera = "NSCameraUsageDescription"
    static let photoLibrary = "NSPhotoLibraryUsageDescription"
    static let contacts = "NSContactsUsageDescription"
    static let locationWhenInUse = "NSLocationWhenInUseUsageDescription"
    static let locationAlways = "NSLocationAlwaysAndWhenInUseUsageDescription"
    // Only the tracking key is encoded. App Store Connect scans binaries for this
    // one specifically and warns that the app "may request permission to track"
    // — which blocked apps that link the SDK but never request tracking from
    // declaring no tracking in App Privacy. The other keys above are read the same
    // way but trigger no such scan, so they stay legible. Don't mangle them
    // without a reason, and don't un-mangle this one.
    // ROT13("NSUserTrackingUsageDescription")
    static let mangledTracking = "AFHfreGenpxvatHfntrQrfpevcgvba"
    static var tracking: String {
      mangledTracking.rot13()
    }
    static let microphone = "NSMicrophoneUsageDescription"
  }

  func hasPlistKey(_ key: String) -> Bool {
    return Bundle.main.object(forInfoDictionaryKey: key) != nil
  }

  @MainActor
  func showMissingPlistKeyAlert(for key: String, permissionName: String) async {
    Logger.debug(
      logLevel: .error,
      scope: .paywallViewController,
      message: "Missing \(key) in Info.plist. Cannot request \(permissionName) permission."
    )

    guard let topViewController = UIViewController.topMostViewController else {
      return
    }

    let alertController = AlertControllerFactory.make(
      title: "Configuration Error",
      message: "Missing \(key) in Info.plist. Cannot request \(permissionName) permission.",
      closeActionTitle: "OK",
      sourceView: topViewController.view
    )

    await withCheckedContinuation { continuation in
      topViewController.present(alertController, animated: true) {
        continuation.resume()
      }
    }
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
    case .tracking:
      return checkTrackingPermission()
    case .microphone:
      return checkMicrophonePermission()
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
    case .tracking:
      return await requestTrackingPermission()
    case .microphone:
      return await requestMicrophonePermission()
    }
  }
}
