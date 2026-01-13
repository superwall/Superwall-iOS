//
//  PermissionsHandler+Location.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

extension PermissionHandler {
  func checkLocationPermission() -> PermissionStatus {
    let proxy = LocationManagerProxy()
    let raw = proxy.authorizationStatus()
    return raw.toLocationPermissionStatus
  }

  @MainActor
  func requestLocationPermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.locationWhenInUse) else {
      await showMissingPlistKeyAlert(for: PlistKey.locationWhenInUse, permissionName: "Location")
      return .unsupported
    }

    let currentStatus = checkLocationPermission()
    if currentStatus == .granted {
      return .granted
    }

    let proxy = LocationManagerProxy()
    let authStatus = proxy.authorizationStatus()

    // Only request if status is notDetermined
    guard authStatus == FakeLocationAuthorizationStatus.notDetermined.rawValue else {
      return currentStatus
    }

    return await withCheckedContinuation { continuation in
      let delegate = LocationPermissionDelegate { status in
        // Only resume if we got a determinate status
        if status != FakeLocationAuthorizationStatus.notDetermined.rawValue {
          continuation.resume(returning: status.toLocationPermissionStatus)
        }
      }
      // Keep a strong reference to the delegate
      self.locationDelegate = delegate
      proxy.setDelegate(delegate)

      let success = proxy.requestWhenInUseAuthorization()
      if !success {
        self.locationDelegate = nil
        continuation.resume(returning: .unsupported)
      }
    }
  }

  func checkBackgroundLocationPermission() -> PermissionStatus {
    #if os(visionOS)
    return .unsupported
    #else
    let proxy = LocationManagerProxy()
    let raw = proxy.authorizationStatus()
    return raw.toBackgroundLocationPermissionStatus
    #endif
  }

  @MainActor
  func requestBackgroundLocationPermission() async -> PermissionStatus {
    #if os(visionOS)
    return .unsupported
    #else
    guard hasPlistKey(PlistKey.locationAlways) else {
      await showMissingPlistKeyAlert(for: PlistKey.locationAlways, permissionName: "Background Location")
      return .unsupported
    }

    let currentStatus = checkBackgroundLocationPermission()
    if currentStatus == .granted {
      return .granted
    }

    // First ensure we have at least when-in-use permission
    let foregroundStatus = checkLocationPermission()
    if foregroundStatus != .granted {
      let requestResult = await requestLocationPermission()
      guard requestResult == .granted else {
        return .denied
      }
    }

    let proxy = LocationManagerProxy()
    let authStatus = proxy.authorizationStatus()

    if authStatus == FakeLocationAuthorizationStatus.authorizedAlways.rawValue {
      return .granted
    }

    return await withCheckedContinuation { continuation in
      let delegate = LocationPermissionDelegate { status in
        // Only resume if we got a determinate status
        if status != FakeLocationAuthorizationStatus.notDetermined.rawValue {
          continuation.resume(returning: status.toBackgroundLocationPermissionStatus)
        }
      }
      // Keep a strong reference to the delegate
      self.locationDelegate = delegate
      proxy.setDelegate(delegate)

      let success = proxy.requestAlwaysAuthorization()
      if !success {
        self.locationDelegate = nil
        continuation.resume(returning: .unsupported)
      }
    }
    #endif
  }
}
