//
//  PermissionHandler+Camera.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import AVFoundation

extension PermissionHandler {
  func checkCameraPermission() -> PermissionStatus {
    return AVCaptureDevice.authorizationStatus(for: .video).toPermissionStatus
  }

  func requestCameraPermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.camera) else {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Missing \(PlistKey.camera) in Info.plist. Cannot request camera permission."
      )
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
