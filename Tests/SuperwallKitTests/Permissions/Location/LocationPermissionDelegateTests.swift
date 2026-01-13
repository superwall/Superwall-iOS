//
//  LocationPermissionDelegateTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct LocationPermissionDelegateTests {
  @Test func callsCallback_whenStatusIsDetermined() {
    var receivedStatus: Int?
    let delegate = LocationPermissionDelegate { status in
      receivedStatus = status
    }

    // Simulate iOS 14+ delegate call with a mock manager
    let mockManager = MockLocationManager()
    mockManager.mockAuthorizationStatus = FakeLocationAuthorizationStatus.authorizedWhenInUse.rawValue
    delegate.locationManagerDidChangeAuthorization(mockManager)

    #expect(receivedStatus == FakeLocationAuthorizationStatus.authorizedWhenInUse.rawValue)
  }

  @Test func doesNotCallCallback_whenStatusIsNotDetermined() {
    var callCount = 0
    let delegate = LocationPermissionDelegate { _ in
      callCount += 1
    }

    let mockManager = MockLocationManager()
    mockManager.mockAuthorizationStatus = FakeLocationAuthorizationStatus.notDetermined.rawValue
    delegate.locationManagerDidChangeAuthorization(mockManager)

    #expect(callCount == 0)
  }

  @Test func callsCallbackOnlyOnce_whenCalledMultipleTimes() {
    var callCount = 0
    let delegate = LocationPermissionDelegate { _ in
      callCount += 1
    }

    let mockManager = MockLocationManager()
    mockManager.mockAuthorizationStatus = FakeLocationAuthorizationStatus.authorizedWhenInUse.rawValue

    delegate.locationManagerDidChangeAuthorization(mockManager)
    delegate.locationManagerDidChangeAuthorization(mockManager)
    delegate.locationManagerDidChangeAuthorization(mockManager)

    #expect(callCount == 1)
  }

  @Test func callsCallback_withDeniedStatus() {
    var receivedStatus: Int?
    let delegate = LocationPermissionDelegate { status in
      receivedStatus = status
    }

    let mockManager = MockLocationManager()
    mockManager.mockAuthorizationStatus = FakeLocationAuthorizationStatus.denied.rawValue
    delegate.locationManagerDidChangeAuthorization(mockManager)

    #expect(receivedStatus == FakeLocationAuthorizationStatus.denied.rawValue)
  }

  @Test func callsCallback_withAuthorizedAlwaysStatus() {
    var receivedStatus: Int?
    let delegate = LocationPermissionDelegate { status in
      receivedStatus = status
    }

    let mockManager = MockLocationManager()
    mockManager.mockAuthorizationStatus = FakeLocationAuthorizationStatus.authorizedAlways.rawValue
    delegate.locationManagerDidChangeAuthorization(mockManager)

    #expect(receivedStatus == FakeLocationAuthorizationStatus.authorizedAlways.rawValue)
  }

  #if !os(visionOS)
  @Test func iOS13DelegateMethod_callsCallback() {
    var receivedStatus: Int?
    let delegate = LocationPermissionDelegate { status in
      receivedStatus = status
    }

    let mockManager = MockLocationManager()
    delegate.locationManager(
      mockManager,
      didChangeAuthorization: FakeLocationAuthorizationStatus.authorizedWhenInUse.rawValue
    )

    #expect(receivedStatus == FakeLocationAuthorizationStatus.authorizedWhenInUse.rawValue)
  }
  #endif
}

// MARK: - Mock

private final class MockLocationManager: NSObject {
  var mockAuthorizationStatus: Int = FakeLocationAuthorizationStatus.notDetermined.rawValue

  override func value(forKey key: String) -> Any? {
    if key == "authorizationStatus" {
      return mockAuthorizationStatus
    }
    return super.value(forKey: key)
  }
}
