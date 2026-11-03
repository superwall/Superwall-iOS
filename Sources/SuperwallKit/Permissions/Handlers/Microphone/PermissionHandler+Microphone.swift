//
//  PermissionHandler+Microphone.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

#if os(macOS)
import AVFoundation
#endif

extension PermissionHandler {
  func checkMicrophonePermission() -> PermissionStatus {
    #if os(macOS)
    // AVAudioSession doesn't exist on macOS. Capture devices carry the
    // microphone permission there, as they do the camera's everywhere.
    return AVCaptureDevice.authorizationStatus(for: .audio).toPermissionStatus
    #else
    let proxy = AudioSessionProxy()
    let raw = proxy.recordPermission()
    guard raw >= 0 else {
      return .unsupported
    }
    return raw.toMicrophonePermissionStatus
    #endif
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

    #if os(macOS)
    let granted = await AVCaptureDevice.requestAccess(for: .audio)
    #else
    let proxy = AudioSessionProxy()
    let granted = await proxy.requestPermission()
    #endif
    return granted ? .granted : .denied
  }
}
