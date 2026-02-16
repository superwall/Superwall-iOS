//
//  TrackingAuthorizationStatusConversionTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct TrackingAuthorizationStatusConversionTests {
  @Test func toTrackingPermissionStatus_notDetermined_returnsDenied() {
    let status = FakeTrackingAuthorizationStatus.notDetermined.rawValue
    #expect(status.toTrackingPermissionStatus == .denied)
  }

  @Test func toTrackingPermissionStatus_restricted_returnsDenied() {
    let status = FakeTrackingAuthorizationStatus.restricted.rawValue
    #expect(status.toTrackingPermissionStatus == .denied)
  }

  @Test func toTrackingPermissionStatus_denied_returnsDenied() {
    let status = FakeTrackingAuthorizationStatus.denied.rawValue
    #expect(status.toTrackingPermissionStatus == .denied)
  }

  @Test func toTrackingPermissionStatus_authorized_returnsGranted() {
    let status = FakeTrackingAuthorizationStatus.authorized.rawValue
    #expect(status.toTrackingPermissionStatus == .granted)
  }

  @Test func toTrackingPermissionStatus_unknownValue_returnsUnsupported() {
    let status = 99
    #expect(status.toTrackingPermissionStatus == .unsupported)
  }
}
