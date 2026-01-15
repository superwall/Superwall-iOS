//
//  MicrophonePermissionTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import AVFoundation
import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct MicrophonePermissionConversionTests {
  @Test func toPermissionStatus_granted_returnsGranted() {
    let status = AVAudioSession.RecordPermission.granted
    #expect(status.toPermissionStatus == .granted)
  }

  @Test func toPermissionStatus_denied_returnsDenied() {
    let status = AVAudioSession.RecordPermission.denied
    #expect(status.toPermissionStatus == .denied)
  }

  @Test func toPermissionStatus_undetermined_returnsDenied() {
    let status = AVAudioSession.RecordPermission.undetermined
    #expect(status.toPermissionStatus == .denied)
  }
}

@Suite
struct PermissionTypeMicrophoneTests {
  @Test func microphoneCase_exists() {
    let permission = PermissionType.microphone
    #expect(permission.rawValue == "microphone")
  }

  @Test func microphone_isDecodable() throws {
    let json = """
    "microphone"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionType.self, from: json)
    #expect(result == .microphone)
  }
}
