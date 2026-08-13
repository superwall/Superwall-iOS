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

  /// Whether `AVAudioSession` is registered with the ObjC runtime is a property of
  /// the runner image — `SuperwallKit` deliberately doesn't link AVFoundation and the
  /// test target declares no `TEST_HOST` — so asserting non-nil outright would fail
  /// CI on an environment fact rather than a defect. Tie both sides to the same fact:
  /// the proxy returns an instance exactly when the class resolves.
  @Test func sharedInstance_matchesWhetherTheClassResolves() {
    let proxy = AudioSessionProxy()
    let classResolves = NSClassFromString(AudioSessionProxy.mangledClassName.rot13()) != nil

    #expect((proxy.sharedInstance() != nil) == classResolves)
  }
}

/// These replace the tests for the deleted `FakeAudioSession`. The fake stood in for
/// `AVAudioSession` when AVFoundation was unavailable, but its `@objc` members emitted
/// Apple's real selector names into the binary — the leak this SDK's mangling exists to
/// prevent. The proxy now guards on a missing class instead, so pin what it returns
/// down that path.
@Suite
struct AudioSessionProxyMissingClassTests {
  @Test func missingSession_sharedInstance_returnsNil() {
    let proxy = AudioSessionProxy(audioSessionClass: nil)
    #expect(proxy.sharedInstance() == nil)
  }

  /// -1 is the "unavailable" sentinel `checkMicrophonePermission()` maps to
  /// `.unsupported`, and is what the fake's `recordPermission()` returned.
  @Test func missingSession_recordPermission_returnsUnavailable() {
    let proxy = AudioSessionProxy(audioSessionClass: nil)
    #expect(proxy.recordPermission() == -1)
  }

  @Test func missingSession_requestPermission_returnsFalse() async {
    let proxy = AudioSessionProxy(audioSessionClass: nil)
    let granted = await proxy.requestPermission()
    #expect(granted == false)
  }
}
