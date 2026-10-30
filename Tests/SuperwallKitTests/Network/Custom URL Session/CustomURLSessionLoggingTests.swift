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

  /// An events batch as the queue sends it: a push token event alongside an
  /// unrelated event that has its own `address` parameter.
  private func eventsRequestWithPushToken() -> EventsRequest {
    let tokenEvent = PlacementData(
      name: PrivateSuperwallEvents.NotificationToken.name,
      parameters: JSON(
        NotificationTokenPayload(
          address: "deadbeefcafef00d",
          apnsEnvironment: .production,
          apnsTopic: "com.example.app",
          authorizationOptions: 7,
          permissionStatus: .authorized,
          enabled: true,
          appVersion: "2.3.4",
          sdkVersion: "4.18.4"
        ).parameters
      ),
      createdAt: Date()
    )
    let otherEvent = PlacementData(
      name: "custom_placement",
      parameters: JSON(["address": "1 Infinite Loop"]),
      createdAt: Date()
    )
    return EventsRequest(events: [tokenEvent.jsonData, otherEvent.jsonData])
  }

  /// Request logs reach the app's logging delegate, so an events batch is
  /// logged without the push token but with everything else.
  @Test func redactsPushTokensFromLoggedEventBodies() throws {
    let body = try EndpointKinds.Superwall.jsonEncoder.encode(eventsRequestWithPushToken())
    #expect(String(data: body, encoding: .utf8)?.contains("deadbeefcafef00d") == true)

    let logged = CustomURLSession.loggableBody(body)

    #expect(!logged.contains("deadbeefcafef00d"))
    #expect(logged.contains(#""address":"<redacted>""#))
    #expect(logged.contains(#""event_name":"notification_token""#))
    #expect(logged.contains(#""apnsTopic":"com.example.app""#))
    #expect(logged.contains(#""permissionStatus":"AUTHORIZED""#))
    // An `address` on any other event is not a push token.
    #expect(logged.contains(#""address":"1 Infinite Loop""#))
  }

  /// A body that might hold a token but isn't valid JSON is never logged raw.
  @Test func neverLogsUnparseableSensitiveBodies() {
    let body = Data(#"{"event_name":"notification_token","address":"deadbeef""#.utf8)
    #expect(!CustomURLSession.loggableBody(body).contains("deadbeef"))
  }

  /// The `/events` failure log reaches the logging delegate too, so it names
  /// the events rather than carrying their parameters.
  @Test func eventsFailureLogInfoHasNoPushToken() {
    let info = eventsRequestWithPushToken().loggableSummary

    #expect(!String(describing: info).contains("deadbeefcafef00d"))
    #expect(info["event_count"] as? Int == 2)
    #expect(info["event_names"] as? [String] == ["notification_token", "custom_placement"])
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
