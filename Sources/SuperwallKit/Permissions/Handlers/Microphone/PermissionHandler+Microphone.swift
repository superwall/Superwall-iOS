//
//  PermissionHandler+Microphone.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

extension PermissionHandler {
  func checkMicrophonePermission() -> PermissionStatus {
    let proxy = AudioSessionProxy()
    let raw = proxy.recordPermission()
    guard raw >= 0 else {
      return .unsupported
    }
    return raw.toMicrophonePermissionStatus
  }

  @MainActor
  func requestMicrophonePermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.microphone) else {
      await showMissingPlistKeyAlert(
        for: PlistKey.microphone,
        permissionName: "Microphone"
      )
      return .unsupported
    }

    if checkMicrophonePermission() == .granted {
      return .granted
    }

    let proxy = AudioSessionProxy()
    let granted = await proxy.requestRecordPermission()
    return granted ? .granted : .denied
  }
}
