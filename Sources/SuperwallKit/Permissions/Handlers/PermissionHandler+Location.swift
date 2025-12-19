//
//  PermissionHandler+Location.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import CoreLocation

extension PermissionHandler {
  func checkLocationPermission() -> PermissionStatus {
    return locationManager.currentAuthorizationStatus.toPermissionStatus
  }

  @MainActor
  func requestLocationPermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.locationWhenInUse) else {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Missing \(PlistKey.locationWhenInUse) in Info.plist. Cannot request location permission."
      )
      return .unsupported
    }

    let currentStatus = checkLocationPermission()
    if currentStatus == .granted {
      return .granted
    }

    let authStatus = locationManager.currentAuthorizationStatus
    guard authStatus == .notDetermined else {
      return currentStatus
    }

    return await withCheckedContinuation { continuation in
      let delegate = LocationPermissionDelegate { [weak self] status in
        self?.locationDelegate = nil
        continuation.resume(returning: status.toPermissionStatus)
      }
      self.locationDelegate = delegate
      self.locationManager.delegate = delegate
      self.locationManager.requestWhenInUseAuthorization()
    }
  }

  func checkBackgroundLocationPermission() -> PermissionStatus {
    #if os(visionOS)
    return .unsupported
    #else
    return locationManager.currentAuthorizationStatus.toBackgroundPermissionStatus
    #endif
  }

  @MainActor
  func requestBackgroundLocationPermission() async -> PermissionStatus {
    #if os(visionOS)
    return .unsupported
    #else
    guard hasPlistKey(PlistKey.locationAlways) else {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Missing \(PlistKey.locationAlways) in Info.plist. Cannot request background location permission."
      )
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

    let authStatus = locationManager.currentAuthorizationStatus
    if authStatus == .authorizedAlways {
      return .granted
    }

    return await withCheckedContinuation { continuation in
      let delegate = LocationPermissionDelegate { [weak self] status in
        self?.locationDelegate = nil
        continuation.resume(returning: status.toBackgroundPermissionStatus)
      }
      self.locationDelegate = delegate
      self.locationManager.delegate = delegate
      self.locationManager.requestAlwaysAuthorization()
    }
    #endif
  }
}
