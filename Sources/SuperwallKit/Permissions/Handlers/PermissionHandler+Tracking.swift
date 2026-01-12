//
//  PermissionHandler+Tracking.swift
//  SuperwallKit
//
//  Created by Superwall on 2025.
//

import AppTrackingTransparency

extension PermissionHandler {
  func checkTrackingPermission() -> PermissionStatus {
    if #available(iOS 14, macCatalyst 14.0, macOS 11.0, tvOS 14.0, *) {
      return ATTrackingManager.trackingAuthorizationStatus.toPermissionStatus
    }
    return .unsupported
  }

  @MainActor
  func requestTrackingPermission() async -> PermissionStatus {
    guard #available(iOS 14, macCatalyst 14.0, macOS 11.0, tvOS 14.0, *) else {
      return .unsupported
    }

    guard hasPlistKey(PlistKey.tracking) else {
      await showMissingPlistKeyAlert(for: PlistKey.tracking, permissionName: "App Tracking Transparency")
      return .unsupported
    }

    let currentStatus = checkTrackingPermission()
    if currentStatus == .granted {
      return .granted
    }

    // ATT can only be requested when status is notDetermined
    guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
      return currentStatus
    }

    let status = await ATTrackingManager.requestTrackingAuthorization()
    return status.toPermissionStatus
  }
}
