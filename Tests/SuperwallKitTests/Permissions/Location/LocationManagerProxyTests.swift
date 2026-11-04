//
//  LocationManagerProxyTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct LocationManagerProxyTests {
  @Test func authorizationStatus_returnsValidStatus() {
    let proxy = LocationManagerProxy()
    let status = proxy.authorizationStatus()

    // Should return a valid CLAuthorizationStatus value (0-4) or notDetermined from fake
    #expect(status >= 0 && status <= 4)
  }

  @Test func selectorNames_areCorrectlyDecoded() {
    let proxy = LocationManagerProxy()

    #expect(proxy.authorizationStatusSelectorName == "authorizationStatus")
    #expect(proxy.requestWhenInUseSelectorName == "requestWhenInUseAuthorization")
    #expect(proxy.requestAlwaysSelectorName == "requestAlwaysAuthorization")
    #expect(proxy.setDelegateSelectorName == "setDelegate:")
  }

  @Test func mangledClassNames_decodeCorrectly() {
    // Verify the ROT13 encoding/decoding is correct
    let className = LocationManagerProxy.mangledLocationManagerClassName.rot13()
    #expect(className == "CLLocationManager")
  }

  @Test func setDelegate_doesNotCrash() {
    let proxy = LocationManagerProxy()
    let delegate = LocationPermissionDelegate { _ in }

    // Should not crash when setting delegate
    proxy.setDelegate(delegate)
  }

  @Test func setDelegate_withNil_doesNotCrash() {
    let proxy = LocationManagerProxy()

    // Should not crash when setting nil delegate
    proxy.setDelegate(nil)
  }
}

// MARK: - Missing CoreLocation Tests

/// These replace the tests for the deleted `FakeLocationManager`. The fake stood in
/// for `CLLocationManager` when CoreLocation was unavailable, but its `@objc` members
/// emitted Apple's real selector names into the binary — the leak this SDK's mangling
/// exists to prevent. The proxy now guards on a missing class instead, so pin what it
/// returns down that path.
@Suite
struct LocationManagerProxyMissingClassTests {
  @Test func missingManager_authorizationStatus_returnsNotDetermined() {
    let proxy = LocationManagerProxy(locationManagerClass: nil)
    #expect(proxy.authorizationStatus() == FakeLocationAuthorizationStatus.notDetermined.rawValue)
  }

  /// Reports failure rather than the fake's silent success. The caller resumes with
  /// `.unsupported` on `false`; with the fake it saw `true` and then waited forever
  /// for a delegate callback the fake never made.
  @Test func missingManager_requestWhenInUseAuthorization_reportsFailure() {
    let proxy = LocationManagerProxy(locationManagerClass: nil)
    #expect(proxy.requestWhenInUseAuthorization() == false)
  }

  @Test func missingManager_requestAlwaysAuthorization_reportsFailure() {
    let proxy = LocationManagerProxy(locationManagerClass: nil)
    #expect(proxy.requestAlwaysAuthorization() == false)
  }

  @Test func missingManager_setDelegate_doesNotCrash() {
    let proxy = LocationManagerProxy(locationManagerClass: nil)
    proxy.setDelegate(LocationPermissionDelegate { _ in })
    proxy.setDelegate(nil)
  }
}
