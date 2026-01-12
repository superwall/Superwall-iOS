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
    if #available(macCatalyst 14.0, *) {
      return AVCaptureDevice.authorizationStatus(for: .video).toPermissionStatus
    }
    return .unsupported
    #else
    return AVCaptureDevice.authorizationStatus(for: .video).toPermissionStatus
    #endif
  }

  @MainActor
  func requestCameraPermission() async -> PermissionStatus {
    #if targetEnvironment(macCatalyst)
    guard #available(macCatalyst 14.0, *) else {
      return .unsupported
    }
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
