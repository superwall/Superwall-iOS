//
//  NotificationEventTrackingTests.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 27/10/2026.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

@Suite(.serialized)
struct NotificationEventTrackingTests {
  private let event = PrivateSuperwallEvents.NotificationToken(
    payload: NotificationTokenPayload(
      address: "deadbeef",
      apnsEnvironment: .production,
      apnsTopic: "com.example.app",
      authorizationOptions: 7,
      permissionStatus: .authorized,
      enabled: true,
      appVersion: "2.3.4",
      sdkVersion: "4.18.3"
    )
  )

  @Test func parameters_areUnprefixed() async {
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "session"
    )
    let params = parameters.audienceFilterParams

    #expect(params["$is_standard_event"] as? Bool == true)
    #expect(params["$event_name"] as? String == "notification_token")
    #expect(params["$app_session_id"] as? String == "session")
    #expect(params["address"] as? String == "deadbeef")
    #expect(params["apnsEnvironment"] as? String == "PRODUCTION")
    #expect(params["$address"] == nil)
  }

  /// Encodes the event exactly as the queue sends it to the collector, to pin
  /// the wire keys: the events encoder converts keys to snake case, but must
  /// leave the parameter dictionary alone.
  @Test func wireShape_keepsCamelCaseKeys() async throws {
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      appSessionId: "session"
    )
    let eventData = PlacementData(
      name: event.rawName,
      parameters: JSON(parameters.audienceFilterParams),
      createdAt: Date()
    )
    let body = try EndpointKinds.Superwall.jsonEncoder.encode(
      EventsRequest(events: [eventData.jsonData])
    )
    let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
    let sent = (json["events"] as! [[String: Any]])[0]

    #expect(sent["event_name"] as? String == "notification_token")
    #expect(sent["event_id"] as? String != nil)
    #expect(sent["created_at"] as? String != nil)

    let params = sent["parameters"] as! [String: Any]
    #expect(params["channel"] as? String == "apns")
    #expect(params["address"] as? String == "deadbeef")
    #expect(params["apnsEnvironment"] as? String == "PRODUCTION")
    #expect(params["apnsTopic"] as? String == "com.example.app")
    #expect(params["authorizationOptions"] as? Int == 7)
    #expect(params["permissionStatus"] as? String == "AUTHORIZED")
    #expect(params["enabled"] as? Bool == true)
    #expect(params["appVersion"] as? String == "2.3.4")
    #expect(params["sdkVersion"] as? String == "4.18.3")
    #expect(params["apns_environment"] == nil)
  }

  @MainActor
  @Test func isQueuedForServer_butNeverReachesTheDelegate() async {
    let dependencyContainer = DependencyContainer()
    let delegate = MockSuperwallDelegate()
    dependencyContainer.delegateAdapter.swiftDelegate = delegate
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    await superwall.track(event)
    await superwall.track(
      PrivateSuperwallEvents.NotificationOpen(sendId: "send_1", contactPointId: "cp_1")
    )
    await superwall.track(InternalSuperwallEvent.AppOpen())

    let queued = await dependencyContainer.placementsQueue.queuedEventNames
    #expect(queued.contains("notification_token"))
    #expect(queued.contains("notification_open"))

    #expect(delegate.eventInfosReceived.count == 1)
    #expect(delegate.eventInfosReceived.first.map { "\($0.event)" } == "app_open")
  }
}
