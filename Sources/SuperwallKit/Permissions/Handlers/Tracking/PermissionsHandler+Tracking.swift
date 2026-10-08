//
//  PermissionsHandler+Tracking.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

extension PermissionHandler {
  func checkTrackingPermission() -> PermissionStatus {
    let proxy = TrackingManagerProxy()
    let raw = proxy.trackingAuthorizationStatus()
    return raw.toTrackingPermissionStatus
  }

  @MainActor
  func requestTrackingPermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.tracking) else {
      await showMissingPlistKeyAlert(
        for: PlistKey.tracking,
        permissionName: "App Tracking Transparency"
      )
      return .unsupported
    }

    let currentStatus = checkTrackingPermission()
    if currentStatus == .granted {
      return .granted
    }

    let proxy = TrackingManagerProxy()
    let authStatus = proxy.trackingAuthorizationStatus()

    // ATT can only be requested when status is notDetermined
    guard authStatus == FakeTrackingAuthorizationStatus.notDetermined.rawValue else {
      return currentStatus
    }

    let status = await proxy.requestAuthorization()
    let permissionStatus = status.toTrackingPermissionStatus

    return permissionStatus
  }
}
