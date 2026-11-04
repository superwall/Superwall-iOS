//
//  CustomURLSessionLoggingTests.swift
//  SuperwallKitTests
//

import Foundation
import Testing
@testable import SuperwallKit

struct CustomURLSessionLoggingTests {
  /// Request logs reach the app's logging delegate, so they never carry the
  /// device's IP addresses, however deeply the body nests them.
  @Test func redactsIPAddressesFromLoggedBodies() throws {
    let body = try JSONSerialization.data(withJSONObject: [
      "platform": "ios",
      "ipV4": "203.0.113.1",
      "ipV4ObservedAt": "2026-09-15T20:43:00Z",
      "ipV6": "2001:db8::1",
      "events": [["params": ["$ipV4": "203.0.113.2", "$ipV6": "2001:db8::2"]]]
    ])

    let logged = CustomURLSession.loggableBody(body)

    #expect(!logged.contains("203.0.113"))
    #expect(!logged.contains("2001:db8"))
    #expect(logged.contains("\"platform\":\"ios\""))
    #expect(logged.contains("2026-09-15T20:43:00Z"))
  }

  @Test func logsOtherBodiesUnchanged() {
    let body = Data(#"{"b":1,"a":"x"}"#.utf8)
    #expect(CustomURLSession.loggableBody(body) == #"{"b":1,"a":"x"}"#)
    #expect(CustomURLSession.loggableBody(nil) == "none")
  }

  @Test func leavesMatchPayloadLogsWithoutAddresses() {
    let request = MMPMatchRequest(
      platform: "ios",
      appUserId: nil,
      deviceId: nil,
      vendorId: nil,
      idfa: nil,
      idfv: nil,
      advertiserTrackingEnabled: false,
      applicationTrackingEnabled: true,
      appVersion: "1",
      sdkVersion: "4",
      osVersion: "27",
      deviceModel: "iPhone",
      deviceLocale: "en_US",
      deviceLanguageCode: "en",
      timezoneOffsetSeconds: 0,
      screenWidth: 1,
      screenHeight: 1,
      devicePixelRatio: 1,
      bundleId: "com.example",
      clientTimestamp: "2026-09-15T20:43:00Z",
      metadata: [:],
      ipV4: "203.0.113.1",
      ipV4ObservedAt: "2026-09-15T20:43:00Z",
      ipV6: "2001:db8::1",
      ipV6ObservedAt: "2026-09-15T20:43:00Z"
    )

    let logged = request.withoutIPAddresses()

    #expect(logged.ipV4 == nil)
    #expect(logged.ipV6 == nil)
    #expect(logged.bundleId == "com.example")
  }
}
