//
//  UserPermissionsImpl.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import AVFoundation
import Contacts
import CoreLocation
import Foundation
import Photos
import UserNotifications

/// Default implementation of UserPermissions using system frameworks.
final class UserPermissionsImpl: UserPermissions {
  private let notificationCenter: UNUserNotificationCenter
  private lazy var locationManager: CLLocationManager = CLLocationManager()

  init(notificationCenter: UNUserNotificationCenter = .current()) {
    self.notificationCenter = notificationCenter
  }

  func hasPermission(_ permission: PermissionType) async -> PermissionStatus {
    switch permission {
    case .notification:
      return await checkNotificationPermission()
    case .location:
      return checkLocationPermission()
    case .background_location:
      return checkBackgroundLocationPermission()
    case .read_images:
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
    case .background_location:
      return await requestBackgroundLocationPermission()
    case .read_images:
      return await requestPhotosPermission()
    case .contacts:
      return await requestContactsPermission()
    case .camera:
      return await requestCameraPermission()
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

  // MARK: - Location Permission

  private func checkLocationPermission() -> PermissionStatus {
    let status = locationManager.authorizationStatus
    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      return .granted
    case .denied, .restricted:
      return .denied
    case .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }

  private func requestLocationPermission() async -> PermissionStatus {
    let currentStatus = checkLocationPermission()
    if currentStatus == .granted {
      return .granted
    }

    // Check if not determined - only then can we request
    let authStatus = locationManager.authorizationStatus
    guard authStatus == .notDetermined else {
      return currentStatus
    }

    return await withCheckedContinuation { continuation in
      let delegate = LocationPermissionDelegate { status in
        let permissionStatus: PermissionStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
          permissionStatus = .granted
        case .denied, .restricted:
          permissionStatus = .denied
        case .notDetermined:
          permissionStatus = .denied
        @unknown default:
          permissionStatus = .unsupported
        }
        continuation.resume(returning: permissionStatus)
      }
      // Keep delegate alive during the request
      objc_setAssociatedObject(
        self.locationManager,
        "locationDelegate",
        delegate,
        .OBJC_ASSOCIATION_RETAIN
      )
      locationManager.delegate = delegate
      locationManager.requestWhenInUseAuthorization()
    }
  }

  // MARK: - Background Location Permission

  private func checkBackgroundLocationPermission() -> PermissionStatus {
    let status = locationManager.authorizationStatus
    switch status {
    case .authorizedAlways:
      return .granted
    case .authorizedWhenInUse, .denied, .restricted:
      return .denied
    case .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }

  private func requestBackgroundLocationPermission() async -> PermissionStatus {
    let currentStatus = checkBackgroundLocationPermission()
    if currentStatus == .granted {
      return .granted
    }

    // First ensure we have at least when-in-use permission
    let foregroundStatus = checkLocationPermission()
    if foregroundStatus != .granted {
      let requestResult = await requestLocationPermission()
      if requestResult != .granted {
        return .denied
      }
    }

    // Now request always authorization
    let authStatus = locationManager.authorizationStatus
    guard authStatus != .authorizedAlways else {
      return .granted
    }

    return await withCheckedContinuation { continuation in
      let delegate = LocationPermissionDelegate { status in
        let permissionStatus: PermissionStatus
        switch status {
        case .authorizedAlways:
          permissionStatus = .granted
        default:
          permissionStatus = .denied
        }
        continuation.resume(returning: permissionStatus)
      }
      objc_setAssociatedObject(
        self.locationManager,
        "locationDelegate",
        delegate,
        .OBJC_ASSOCIATION_RETAIN
      )
      locationManager.delegate = delegate
      locationManager.requestAlwaysAuthorization()
    }
  }

  // MARK: - Photos Permission

  private func checkPhotosPermission() -> PermissionStatus {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    switch status {
    case .authorized, .limited:
      return .granted
    case .denied, .restricted:
      return .denied
    case .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }

  private func requestPhotosPermission() async -> PermissionStatus {
    let currentStatus = checkPhotosPermission()
    if currentStatus == .granted {
      return .granted
    }

    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    switch status {
    case .authorized, .limited:
      return .granted
    case .denied, .restricted:
      return .denied
    case .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }

  // MARK: - Contacts Permission

  private func checkContactsPermission() -> PermissionStatus {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    switch status {
    case .authorized:
      return .granted
    case .denied, .restricted:
      return .denied
    case .notDetermined:
      return .denied
    case .limited:
      return .granted
    @unknown default:
      return .unsupported
    }
  }

  private func requestContactsPermission() async -> PermissionStatus {
    let currentStatus = checkContactsPermission()
    if currentStatus == .granted {
      return .granted
    }

    let store = CNContactStore()
    do {
      let granted = try await store.requestAccess(for: .contacts)
      return granted ? .granted : .denied
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Error requesting contacts permission",
        error: error
      )
      return .denied
    }
  }

  // MARK: - Camera Permission

  private func checkCameraPermission() -> PermissionStatus {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
      return .granted
    case .denied, .restricted:
      return .denied
    case .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }

  private func requestCameraPermission() async -> PermissionStatus {
    let currentStatus = checkCameraPermission()
    if currentStatus == .granted {
      return .granted
    }

    let granted = await AVCaptureDevice.requestAccess(for: .video)
    return granted ? .granted : .denied
  }
}

// MARK: - Location Permission Delegate

private final class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
  private let completion: (CLAuthorizationStatus) -> Void
  private var hasCompleted = false

  init(completion: @escaping (CLAuthorizationStatus) -> Void) {
    self.completion = completion
    super.init()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    // Only complete if status has been determined
    guard status != .notDetermined, !hasCompleted else { return }
    hasCompleted = true
    completion(status)
  }
}
