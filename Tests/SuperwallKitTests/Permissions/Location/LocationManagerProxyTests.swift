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

// MARK: - FakeLocationManager Tests

@Suite
struct FakeLocationManagerTests {
  @Test func authorizationStatus_returnsNotDetermined() {
    let manager = FakeLocationManager()
    #expect(manager.authorizationStatus == FakeLocationAuthorizationStatus.notDetermined.rawValue)
  }

  @Test func requestWhenInUseAuthorization_doesNotCrash() {
    let manager = FakeLocationManager()
    manager.requestWhenInUseAuthorization()
    // Should complete without crashing
  }

  @Test func requestAlwaysAuthorization_doesNotCrash() {
    let manager = FakeLocationManager()
    manager.requestAlwaysAuthorization()
    // Should complete without crashing
  }

  @Test func delegate_canBeSet() {
    let manager = FakeLocationManager()
    let delegate = NSObject()

    manager.delegate = delegate
    #expect(manager.delegate === delegate)
  }

  @Test func delegate_isWeak() {
    let manager = FakeLocationManager()

    autoreleasepool {
      let delegate = NSObject()
      manager.delegate = delegate
      #expect(manager.delegate != nil)
    }

    // After autoreleasepool, the delegate should be deallocated
    #expect(manager.delegate == nil)
  }
}
