//
//  TrackingManagerProxyTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct TrackingManagerProxyTests {
  @Test func selectorNames_areCorrectlyDecoded() {
    let proxy = TrackingManagerProxy()

    #expect(proxy.trackingStatusSelectorName == "trackingAuthorizationStatus")
    #expect(
      proxy.requestTrackingSelectorName == "requestTrackingAuthorizationWithCompletionHandler:"
    )
  }

  @Test func mangledClassName_decodesCorrectly() {
    // Verify the ROT13 encoding/decoding is correct
    let className = TrackingManagerProxy.mangledTrackingManagerClassName.rot13()
    #expect(className == "ATTrackingManager")
  }

  @Test func trackingAuthorizationStatus_returnsValidStatus() {
    let proxy = TrackingManagerProxy()
    let status = proxy.trackingAuthorizationStatus()

    // Should return a valid ATTrackingManager.AuthorizationStatus value (0-3)
    #expect(status >= 0 && status <= 3)
  }

  @Test func trackingPlistKey_isCorrectlyDecoded() {
    #expect(PermissionHandler.PlistKey.tracking == "NSUserTrackingUsageDescription")
  }

  @Test func missingManager_trackingAuthorizationStatus_returnsNotDetermined() {
    let proxy = TrackingManagerProxy(trackingManagerClass: nil)
    let status = proxy.trackingAuthorizationStatus()

    #expect(status == FakeTrackingAuthorizationStatus.notDetermined.rawValue)
  }

  @Test func missingManager_requestAuthorization_returnsNotDetermined() async {
    let proxy = TrackingManagerProxy(trackingManagerClass: nil)
    let status = await proxy.requestAuthorization()

    #expect(status == FakeTrackingAuthorizationStatus.notDetermined.rawValue)
  }
}
