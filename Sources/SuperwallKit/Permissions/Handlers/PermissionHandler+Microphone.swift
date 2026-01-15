//
//  PermissionHandler+Microphone.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import AVFoundation

extension PermissionHandler {
  func checkMicrophonePermission() -> PermissionStatus {
    return AVAudioSession.sharedInstance().recordPermission.toPermissionStatus
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

    let currentStatus = checkMicrophonePermission()
    if currentStatus == .granted {
      return .granted
    }

    return await withCheckedContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        continuation.resume(returning: granted ? .granted : .denied)
      }
    }
  }
}
