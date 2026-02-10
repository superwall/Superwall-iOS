//
//  MicrophonePermissionTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct MicrophonePermissionConversionTests {
  // AVAudioSession.RecordPermission raw values:
  // 0x67726e74 ('grnt') = granted
  // 0x64656e79 ('deny') = denied
  // 0x756e6474 ('undt') = undetermined

  @Test func toMicrophonePermissionStatus_granted_returnsGranted() {
    let rawValue = 0x67726e74 // 'grnt'
    #expect(rawValue.toMicrophonePermissionStatus == .granted)
  }

  @Test func toMicrophonePermissionStatus_denied_returnsDenied() {
    let rawValue = 0x64656e79 // 'deny'
    #expect(rawValue.toMicrophonePermissionStatus == .denied)
  }

  @Test func toMicrophonePermissionStatus_undetermined_returnsDenied() {
    let rawValue = 0x756e6474 // 'undt'
    #expect(rawValue.toMicrophonePermissionStatus == .denied)
  }

  @Test func toMicrophonePermissionStatus_unknownValue_returnsUnsupported() {
    let rawValue = 0x12345678 // unknown value
    #expect(rawValue.toMicrophonePermissionStatus == .unsupported)
  }

  @Test func toMicrophonePermissionStatus_negativeValue_returnsUnsupported() {
    let rawValue = -1
    #expect(rawValue.toMicrophonePermissionStatus == .unsupported)
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

@Suite
struct AudioSessionProxyTests {
  @Test func recordPermission_returnsValidValue() {
    let proxy = AudioSessionProxy()
    let result = proxy.recordPermission()

    // Should return either a valid permission value or -1 if unavailable
    let validValues = [
      0x67726e74, // granted
      0x64656e79, // denied
      0x756e6474, // undetermined
      -1 // unavailable/fake
    ]
    #expect(validValues.contains(result))
  }

  @Test func sharedInstance_returnsNonNil() {
    let proxy = AudioSessionProxy()
    // In test environment, this should return either real AVAudioSession or FakeAudioSession
    let instance = proxy.sharedInstance()
    #expect(instance != nil)
  }
}

@Suite
struct FakeAudioSessionTests {
  @Test func sharedInstance_returnsFakeAudioSession() {
    let instance = FakeAudioSession.sharedInstance()
    #expect(instance is FakeAudioSession)
  }

  @Test func recordPermission_returnsNegativeOne() {
    let fake = FakeAudioSession()
    #expect(fake.recordPermission() == -1)
  }

  @Test func requestRecordPermission_callsCompletionWithFalse() {
    let fake = FakeAudioSession()
    var result: Bool?

    fake.requestRecordPermission { granted in
      result = granted
    }

    #expect(result == false)
  }
}
