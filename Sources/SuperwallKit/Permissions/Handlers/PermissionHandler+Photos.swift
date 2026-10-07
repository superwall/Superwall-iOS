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
    status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
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

    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    return status.toPermissionStatus
  }
}
