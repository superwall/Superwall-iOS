//
//  LocationAuthorizationStatusConversionTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct LocationAuthorizationStatusConversionTests {
  // MARK: - toLocationPermissionStatus

  @Test func toLocationPermissionStatus_notDetermined_returnsDenied() {
    let status = FakeLocationAuthorizationStatus.notDetermined.rawValue
    #expect(status.toLocationPermissionStatus == .denied)
  }

  @Test func toLocationPermissionStatus_restricted_returnsDenied() {
    let status = FakeLocationAuthorizationStatus.restricted.rawValue
    #expect(status.toLocationPermissionStatus == .denied)
  }

  @Test func toLocationPermissionStatus_denied_returnsDenied() {
    let status = FakeLocationAuthorizationStatus.denied.rawValue
    #expect(status.toLocationPermissionStatus == .denied)
  }

  @Test func toLocationPermissionStatus_authorizedAlways_returnsGranted() {
    let status = FakeLocationAuthorizationStatus.authorizedAlways.rawValue
    #expect(status.toLocationPermissionStatus == .granted)
  }

  @Test func toLocationPermissionStatus_authorizedWhenInUse_returnsGranted() {
    let status = FakeLocationAuthorizationStatus.authorizedWhenInUse.rawValue
    #expect(status.toLocationPermissionStatus == .granted)
  }

  @Test func toLocationPermissionStatus_unknownValue_returnsUnsupported() {
    let status = 99
    #expect(status.toLocationPermissionStatus == .unsupported)
  }

  // MARK: - toBackgroundLocationPermissionStatus

  @Test func toBackgroundLocationPermissionStatus_notDetermined_returnsDenied() {
    let status = FakeLocationAuthorizationStatus.notDetermined.rawValue
    #expect(status.toBackgroundLocationPermissionStatus == .denied)
  }

  @Test func toBackgroundLocationPermissionStatus_restricted_returnsDenied() {
    let status = FakeLocationAuthorizationStatus.restricted.rawValue
    #expect(status.toBackgroundLocationPermissionStatus == .denied)
  }

  @Test func toBackgroundLocationPermissionStatus_denied_returnsDenied() {
    let status = FakeLocationAuthorizationStatus.denied.rawValue
    #expect(status.toBackgroundLocationPermissionStatus == .denied)
  }

  @Test func toBackgroundLocationPermissionStatus_authorizedAlways_returnsGranted() {
    let status = FakeLocationAuthorizationStatus.authorizedAlways.rawValue
    #expect(status.toBackgroundLocationPermissionStatus == .granted)
  }

  @Test func toBackgroundLocationPermissionStatus_authorizedWhenInUse_returnsDenied() {
    // When-in-use is NOT sufficient for background location
    let status = FakeLocationAuthorizationStatus.authorizedWhenInUse.rawValue
    #expect(status.toBackgroundLocationPermissionStatus == .denied)
  }

  @Test func toBackgroundLocationPermissionStatus_unknownValue_returnsUnsupported() {
    let status = 99
    #expect(status.toBackgroundLocationPermissionStatus == .unsupported)
  }
}
