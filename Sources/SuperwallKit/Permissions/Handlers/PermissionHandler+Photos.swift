//
//  PermissionHandler+Photos.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import Photos

extension PermissionHandler {
  func checkPhotosPermission() -> PermissionStatus {
    let status: PHAuthorizationStatus
    if #available(iOS 14, *) {
      status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    } else {
      status = PHPhotoLibrary.authorizationStatus()
    }
    return status.toPermissionStatus
  }

  @MainActor
  func requestPhotosPermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.photoLibrary) else {
      await showMissingPlistKeyAlert(for: PlistKey.photoLibrary, permissionName: "Photo Library")
      return .unsupported
    }

    let currentStatus = checkPhotosPermission()
    if currentStatus == .granted {
      return .granted
    }

    if #available(iOS 14, *) {
      let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
      return status.toPermissionStatus
    } else {
      return await withCheckedContinuation { continuation in
        PHPhotoLibrary.requestAuthorization { status in
          continuation.resume(returning: status.toPermissionStatus)
        }
      }
    }
  }
}
