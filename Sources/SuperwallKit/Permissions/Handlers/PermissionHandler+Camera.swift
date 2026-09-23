//
//  PermissionHandler+Camera.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import AVFoundation

extension PermissionHandler {
  func checkCameraPermission() -> PermissionStatus {
    #if targetEnvironment(macCatalyst)
    return AVCaptureDevice.authorizationStatus(for: .video).toPermissionStatus
    return .unsupported
    #else
    return AVCaptureDevice.authorizationStatus(for: .video).toPermissionStatus
    #endif
  }

  @MainActor
  func requestCameraPermission() async -> PermissionStatus {
    #if targetEnvironment(macCatalyst)
    #endif

    guard hasPlistKey(PlistKey.camera) else {
      await showMissingPlistKeyAlert(for: PlistKey.camera, permissionName: "Camera")
      return .unsupported
    }

    let currentStatus = checkCameraPermission()
    if currentStatus == .granted {
      return .granted
    }

    let granted = await AVCaptureDevice.requestAccess(for: .video)
    return granted ? .granted : .denied
  }
}
